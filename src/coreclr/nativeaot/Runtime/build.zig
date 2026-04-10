const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const wasi_target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });

    const gc_dir = "../../gc";
    const runtime_dir = "../../runtime";

    const include_dirs = [_][]const u8{
        "inc",
        ".",
        gc_dir,
        gc_dir ++ "/env",
        runtime_dir,
        "unix",
        "../../pal/inc/rt",
        "wasm",
        "../../../native",
        "../../../native/inc",
        "generated",
        "generated/minipal/..",
    };

    const defines = [_]struct { []const u8, []const u8 }{
        .{ "FEATURE_NATIVEAOT", "1" },
        .{ "NATIVEAOT", "1" },
        .{ "FEATURE_BASICFREEZE", "1" },
        .{ "FEATURE_CONSERVATIVE_GC", "1" },
        .{ "FEATURE_64BIT_ALIGNMENT", "1" },
        .{ "FEATURE_CUSTOM_IMPORTS", "1" },
        .{ "FEATURE_DYNAMIC_CODE", "1" },
        .{ "FEATURE_CACHED_INTERFACE_DISPATCH", "1" },
        .{ "FEATURE_PORTABLE_HELPERS", "1" },
        .{ "VERIFY_HEAP", "1" },
        .{ "_LIB", "1" },
        .{ "TARGET_WASI", "1" },
.{ "TARGET_WASM", "1" },
        .{ "TARGET_32BIT", "1" },
        .{ "TARGET_UNIX", "1" },
        .{ "DISABLE_CONTRACTS", "1" },
        .{ "PLATFORM_UNIX", "1" },
.{ "HOST_WASM", "1" },
        .{ "_WASI_EMULATED_SIGNAL", "1" },
        .{ "_WASI_EMULATED_MMAN", "1" },
        .{ "_WASI_EMULATED_PROCESS_CLOCKS", "1" },
        .{ "_WASI_EMULATED_GETPID", "1" },
    };

    const cpp_flags = [_][]const u8{"-std=c++17", "-Wno-invalid-offsetof"};

    const runtime_sources = [_][]const u8{
        "allocheap.cpp", "rhassert.cpp",
        runtime_dir ++ "/CachedInterfaceDispatch.cpp", "CachedInterfaceDispatch_Aot.cpp",
        "Crst.cpp", "DebugHeader.cpp", "MethodTable.cpp", "EHHelpers.cpp", "event.cpp",
        "GcEnum.cpp", "GCHelpers.cpp", "gctoclreventsink.cpp", "gcheaputilities.cpp",
        "GCMemoryHelpers.cpp", "gcenv.ee.cpp", "GcStressControl.cpp", "HandleTableHelpers.cpp",
        "interoplibinterface_java.cpp", "MathHelpers.cpp", "MiscHelpers.cpp",
        "TypeManager.cpp", "ObjectLayout.cpp", "portable.cpp", "RestrictedCallouts.cpp",
        "RhConfig.cpp", "RuntimeInstance.cpp", "StackFrameIterator.cpp", "startup.cpp",
        "stressLog.cpp", "SyncClean.cpp", "thread.cpp", "threadstore.cpp",
        "UniversalTransitionHelpers.cpp", "yieldprocessornormalized.cpp",
        gc_dir ++ "/gceventstatus.cpp", gc_dir ++ "/gcbridge.cpp",
        gc_dir ++ "/gcload.cpp", gc_dir ++ "/gcconfig.cpp", gc_dir ++ "/gchandletable.cpp",
        gc_dir ++ "/gccommon.cpp", gc_dir ++ "/gceewks.cpp", gc_dir ++ "/gcwks.cpp",
        gc_dir ++ "/gcscan.cpp", gc_dir ++ "/handletable.cpp",
        gc_dir ++ "/handletablecache.cpp", gc_dir ++ "/handletablecore.cpp",
        gc_dir ++ "/handletablescan.cpp", gc_dir ++ "/objecthandle.cpp",
        gc_dir ++ "/softwarewritewatch.cpp",
        "unix/PalUnix.cpp",
        gc_dir ++ "/unix/gcenv.unix.cpp", gc_dir ++ "/unix/numasupport.cpp",
        gc_dir ++ "/unix/events.cpp", gc_dir ++ "/wasm/gcenv.wasm.cpp",
        "wasm/PalCreateDump.cpp", "wasm/cgroupcpu.cpp",
        "wasm/FinalizerHelpers.SingleThreaded.cpp", "wasm/PalWasm.cpp",
        "wasm/AllocFast.cpp", "wasm/ExceptionHandling/ExceptionHandling.cpp",
        "wasm/GcStress.cpp", "wasm/PInvoke.cpp",
        "wasm/StubDispatch.cpp", "wasm/WriteBarriers.cpp",
        "wasm/StackTrace.cpp",
    };

    const SetupMod = struct {
        fn setup(mod: *std.Build.Module, inc: []const []const u8, defs: []const struct { []const u8, []const u8 }, owner: *std.Build) void {
            for (inc) |dir| mod.addIncludePath(owner.path(dir));
            for (defs) |d| mod.addCMacro(d[0], d[1]);
        }
    };

    // --- libPortableRuntime.a ---
    const rt_mod = b.createModule(.{ .target = wasi_target, .optimize = optimize, .link_libc = true, .link_libcpp = true });
    SetupMod.setup(rt_mod, &include_dirs, &defines, b);
    rt_mod.addCSourceFiles(.{ .files = &runtime_sources, .flags = &cpp_flags });
    rt_mod.addCSourceFile(.{ .file = b.path("../../../native/minipal/xoshiro128pp.c") });
    b.installArtifact(b.addLibrary(.{ .name = "PortableRuntime", .root_module = rt_mod }));

    // --- libstandalonegc-disabled.a ---
    const gc_mod = b.createModule(.{ .target = wasi_target, .optimize = optimize, .link_libc = true, .link_libcpp = true });
    SetupMod.setup(gc_mod, &include_dirs, &defines, b);
    gc_mod.addCSourceFiles(.{ .files = &.{"clrgc.disabled.cpp"}, .flags = &cpp_flags });
    b.installArtifact(b.addLibrary(.{ .name = "standalonegc-disabled", .root_module = gc_mod }));

    // --- WasmExceptionHandling (needs exception-handling + reference-types features) ---
    var wasi_eh_query = std.Target.Query{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    };
    wasi_eh_query.cpu_features_add = std.Target.wasm.featureSet(&.{ .exception_handling, .reference_types });
    const wasi_eh_target = b.resolveTargetQuery(wasi_eh_query);
    const weh_mod = b.createModule(.{ .target = wasi_eh_target, .optimize = optimize, .link_libc = true, .link_libcpp = true });
    SetupMod.setup(weh_mod, &include_dirs, &defines, b);
    weh_mod.addCSourceFiles(.{ .files = &.{"wasm/ExceptionHandling/ExceptionHandling.Wasm.cpp"}, .flags = &.{ "-std=c++17", "-Wno-invalid-offsetof", "-fwasm-exceptions", "-mexception-handling", "-mreference-types" } });
    b.installArtifact(b.addLibrary(.{ .name = "WasmExceptionHandling", .root_module = weh_mod }));

    // --- CppExceptionHandling ---
    const ceh_mod = b.createModule(.{ .target = wasi_target, .optimize = optimize, .link_libc = true, .link_libcpp = true });
    SetupMod.setup(ceh_mod, &include_dirs, &defines, b);
    ceh_mod.addCSourceFiles(.{ .files = &.{"wasm/ExceptionHandling/ExceptionHandling.Cpp.cpp"}, .flags = &.{ "-std=c++17", "-Wno-invalid-offsetof", "-fexceptions" } });
    b.installArtifact(b.addLibrary(.{ .name = "CppExceptionHandling", .root_module = ceh_mod }));

    // --- EmulatedExceptionHandling ---
    const eeh_mod = b.createModule(.{ .target = wasi_target, .optimize = optimize, .link_libc = true, .link_libcpp = true });
    SetupMod.setup(eeh_mod, &include_dirs, &defines, b);
    eeh_mod.addCSourceFiles(.{ .files = &.{"wasm/ExceptionHandling/ExceptionHandling.Emulated.cpp"}, .flags = &cpp_flags });
    b.installArtifact(b.addLibrary(.{ .name = "EmulatedExceptionHandling", .root_module = eeh_mod }));
}
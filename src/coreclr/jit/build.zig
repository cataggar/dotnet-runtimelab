const std = @import("std");

/// Build the NativeAOT-LLVM JIT shared library using zig.
///
/// This produces libclrjit_universal_llvm32_<host>.so/.dylib/.dll
/// which is the LLVM bitcode-emitting JIT used by ILC for WASI targets.
///
/// Prerequisites:
///   - LLVM 18.x installed (headers + LLVMCore.a + LLVMBitWriter.a)
///   - Set LLVM_CMAKE_CONFIG env var to the LLVM cmake dir, e.g.:
///     export LLVM_CMAKE_CONFIG=/path/to/llvm/lib/cmake/llvm
///   - Or pass -Dllvm-prefix=/path/to/llvm
///
/// Usage:
///   zig build -Dllvm-prefix=/path/to/llvm-install -Doptimize=ReleaseFast
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // LLVM install prefix (contains include/ and lib/)
    const llvm_prefix: []const u8 = b.option([]const u8, "llvm-prefix", "Path to LLVM install (with include/ and lib/)") orelse
        @panic("Set -Dllvm-prefix=/path/to/llvm");

    const jit_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
        .pic = true,
    });

    // --- Include directories ---
    // The JIT depends on many PAL (Platform Abstraction Layer) headers
    const repo_root = "../../.."; // from src/coreclr/jit/ to repo root
    const include_dirs = [_][]const u8{
        ".", // jit/
        "jitstd",
        "../inc",
        "../tools/Common/JitInterface",
        "../pal/inc",
        "../pal/inc/rt",
        "../pal/prebuilt/inc",
        "../pal/src/safecrt",
        "../debug/inc",
        "../debug/inc/amd64",
        "../debug/inc/dump",
        "../md/inc",
        "../classlibnative/bcltype",
        "../classlibnative/inc",
        "../hosts/inc",
        "../interpreter/inc",
        "../minipal",
        "../nativeresources",
        repo_root ++ "/src/native",
        repo_root ++ "/src/native/inc",
    };
    for (include_dirs) |dir| {
        jit_mod.addIncludePath(b.path(dir));
    }

    // cmake-generated headers (version info, config). These are in artifacts/obj/ but
    // for a standalone build we'd need to generate them. For now, point to existing.
    if (b.option([]const u8, "generated-inc", "Path to cmake-generated inc/ dir")) |gen_inc| {
        jit_mod.addIncludePath(.{ .cwd_relative = gen_inc });
    }

    // LLVM includes
    const llvm_include = b.fmt("{s}/include", .{llvm_prefix});
    jit_mod.addSystemIncludePath(.{ .cwd_relative = llvm_include });

    // --- Preprocessor defines ---
    const defines = [_]struct { []const u8, []const u8 }{
        .{ "JIT_BUILD", "1" },
        .{ "JIT_STANDALONE_BUILD", "1" },
        .{ "FEATURE_NO_HOST", "1" },
        .{ "SELF_NO_HOST", "1" },
        .{ "TARGET_LLVM", "1" },
        .{ "TARGET_LLVM_WASM32", "1" },
        .{ "TARGET_WASM", "1" },
        .{ "TARGET_WASM32", "1" },
        .{ "TARGET_32BIT", "1" },
        .{ "TARGET_UNIX", "1" },
        .{ "HOST_64BIT", "1" },
        .{ "HOST_AMD64", "1" },
        .{ "HOST_UNIX", "1" },
        .{ "UNICODE", "1" },
        .{ "_UNICODE", "1" },
        .{ "UNIX_AMD64_ABI_ITF", "1" },
        .{ "DISABLE_CONTRACTS", "1" },
        .{ "FEATURE_BASICFREEZE", "1" },
        .{ "FEATURE_CORECLR", "1" },
        .{ "FEATURE_PAL_ANSI", "1" },
        .{ "FEATURE_JIT", "1" },
        .{ "FEATURE_READYTORUN", "1" },
        .{ "FEATURE_INTERPRETER", "1" },
        .{ "_FILE_OFFSET_BITS", "64" },
        .{ "__STDC_CONSTANT_MACROS", "1" },
        .{ "__STDC_FORMAT_MACROS", "1" },
        .{ "__STDC_LIMIT_MACROS", "1" },
    };
    for (defines) |d| {
        jit_mod.addCMacro(d[0], d[1]);
    }

    // --- Source files ---
    // Base JIT sources (shared across all targets)
    const jit_sources = [_][]const u8{
        "abi.cpp",
        "alloc.cpp",
        "assertionprop.cpp",
        "async.cpp",
        "bitset.cpp",
        "block.cpp",
        "buildstring.cpp",
        "compiler.cpp",
        "copyprop.cpp",
        "debuginfo.cpp",
        "disasm.cpp",
        "earlyprop.cpp",
        "ee_il_dll.cpp",
        "eeinterface.cpp",
        "error.cpp",
        "fgbasic.cpp",
        "fgdiagnostic.cpp",
        "fgehopt.cpp",
        "fgflow.cpp",
        "fginline.cpp",
        "fgopt.cpp",
        "fgprofile.cpp",
        "fgprofilesynthesis.cpp",
        "fgstmt.cpp",
        "flowgraph.cpp",
        "forwardsub.cpp",
        "gcdecode.cpp",
        "gcinfo.cpp",
        "gentree.cpp",
        "gschecks.cpp",
        "hashbv.cpp",
        "helperexpansion.cpp",
        "hostallocator.cpp",
        "hwintrinsic.cpp",
        "ifconversion.cpp",
        "importer.cpp",
        "importercalls.cpp",
        "importervectorization.cpp",
        "indirectcalltransformer.cpp",
        "inductionvariableopts.cpp",
        "inline.cpp",
        "inlinepolicy.cpp",
        "jitconfig.cpp",
        "jiteh.cpp",
        "jithashtable.cpp",
        "jitmetadata.cpp",
        "layout.cpp",
        "lclmorph.cpp",
        "lclvars.cpp",
        "likelyclass.cpp",
        "lir.cpp",
        "liveness.cpp",
        "loopcloning.cpp",
        "morph.cpp",
        "morphblock.cpp",
        "objectalloc.cpp",
        "optcse.cpp",
        "optimizebools.cpp",
        "optimizemaskconversions.cpp",
        "optimizer.cpp",
        "patchpoint.cpp",
        "phase.cpp",
        "promotion.cpp",
        "promotiondecomposition.cpp",
        "promotionliveness.cpp",
        "rangecheck.cpp",
        "rangecheckcloning.cpp",
        "rationalize.cpp",
        "redundantbranchopts.cpp",
        "regMaskTPOps.cpp",
        "regset.cpp",
        "scev.cpp",
        "scopeinfo.cpp",
        "segmentlist.cpp",
        "sideeffects.cpp",
        "sm.cpp",
        "smdata.cpp",
        "smweights.cpp",
        "ssabuilder.cpp",
        "ssarenamestate.cpp",
        "switchrecognition.cpp",
        "treelifeupdater.cpp",
        "utils.cpp",
        "valuenum.cpp",
        "dllmain.cpp",
    };

    // WASM32/LLVM-specific sources (replaces arch-specific codegen)
    const jit_wasm32_sources = [_][]const u8{
        "targetllvm.cpp",
        "llvm.cpp",
        "llvmtypes.cpp",
        "llvmlower.cpp",
        "llvmlssa.cpp",
        "llvmcodegen.cpp",
        "llvmdebuginfo.cpp",
    };

    // NOTE: These files from JIT_SOURCES are EXCLUDED for wasm32 because
    // the LLVM backend replaces native codegen:
    //   codegencommon.cpp, codegenlinear.cpp, emit.cpp, gcencode.cpp,
    //   instr.cpp, lower.cpp, lsra.cpp, lsrabuild.cpp,
    //   stacklevelsetter.cpp, regalloc.cpp

    const cpp_flags = [_][]const u8{
        "-std=c++17",
        "-include", "jitpch.h",
        "-fvisibility=hidden",
        "-fsigned-char",
        "-fno-rtti",
        "-fno-strict-aliasing",
        "-ffp-contract=off",
        // Suppress warnings from PAL headers and JIT code
        "-Wno-invalid-offsetof",
        "-Wno-pragma-pack",
        "-Wno-incompatible-ms-struct",
        "-Wno-reserved-identifier",
        "-Wno-unused-variable",
        "-Wno-unused-value",
        "-Wno-unused-function",
        "-Wno-unused-private-field",
        "-Wno-unused-but-set-variable",
        "-Wno-tautological-compare",
        "-Wno-unknown-pragmas",
        "-Wno-null-arithmetic",
        "-Wno-sync-alignment",
        "-Wno-constant-logical-operand",
        "-Wno-single-bit-bitfield-constant-conversion",
        "-Wno-cast-function-type-strict",
        "-Wno-switch-default",
        "-Wno-nontrivial-memaccess",
        "-Wno-unsafe-buffer-usage",
        "-Wno-unused-lambda-capture",
        "-Wno-extra-tokens", // #endif; in compiler.h
    };

    jit_mod.addCSourceFiles(.{ .files = &jit_sources, .flags = &cpp_flags });
    jit_mod.addCSourceFiles(.{ .files = &jit_wasm32_sources, .flags = &cpp_flags });

    // --- Link LLVM static libraries ---
    const llvm_lib = b.fmt("{s}/lib", .{llvm_prefix});
    jit_mod.addLibraryPath(.{ .cwd_relative = llvm_lib });

    // LLVM components: core + bitwriter (matching CMakeLists.txt)
    jit_mod.linkSystemLibrary("LLVMCore", .{});
    jit_mod.linkSystemLibrary("LLVMBitWriter", .{});
    jit_mod.linkSystemLibrary("LLVMBinaryFormat", .{});
    jit_mod.linkSystemLibrary("LLVMRemarks", .{});
    jit_mod.linkSystemLibrary("LLVMBitstreamReader", .{});
    jit_mod.linkSystemLibrary("LLVMSupport", .{});
    jit_mod.linkSystemLibrary("LLVMDemangle", .{});

    const jit = b.addLibrary(.{ .name = "clrjit_universal_llvm32", .root_module = jit_mod, .linkage = .dynamic });
    b.installArtifact(jit);
}

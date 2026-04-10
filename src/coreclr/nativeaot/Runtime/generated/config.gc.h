// Licensed to the .NET Foundation under one or more agreements.
// The .NET Foundation licenses this file to you under the MIT license.

#ifndef __CONFIG_H__
#define __CONFIG_H__

#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_MMAN_H 1
#define HAVE_SYS_MEMBARRIER_H 1
#define HAVE_PTHREAD_THREADID_NP 0
#define HAVE_PTHREAD_GETTHREADID_NP 0
#define HAVE_VM_FLAGS_SUPERPAGE_SIZE_ANY 0
#define HAVE_MAP_HUGETLB 1
#define HAVE_SCHED_GETCPU 0
#define HAVE_VM_ALLOCATE 0
#define HAVE_SWAPCTL 0
#define HAVE_SYSCTLBYNAME 0
#define HAVE_PTHREAD_CONDATTR_SETCLOCK 0
#define HAVE_CLOCK_GETTIME_NSEC_NP 0
#define HAVE_SCHED_GETAFFINITY 0
#define HAVE_SCHED_SETAFFINITY 0
#define HAVE_PTHREAD_SETAFFINITY_NP 0
#define HAVE_PTHREAD_NP_H 0
#define HAVE_POSIX_MADVISE 0
#define HAVE_CPUSET_T 0
#define HAVE__SC_AVPHYS_PAGES 1
#define HAVE__SC_PHYS_PAGES 1
#define HAVE_SYSCONF 1
#define HAVE_SYSCTL 0
#define HAVE_SYSINFO 0
#define HAVE_SYSINFO_WITH_MEM_UNIT 1
#define HAVE_XSW_USAGE 0
#define HAVE_XSWDEV 0
#if !TARGET_WASM // emscripten configure test passes for this, but the f_type on the statfs is not recognized and fails https://github.com/dotnet/runtimelab/blob/e5c4d674afdf758adf12052d64c120ce9030048b/src/coreclr/src/gc/unix/cgroup.cpp#L152
#define HAVE_NON_LEGACY_STATFS  1
#endif
#define HAVE_PROCFS_STATM 1

#endif // __CONFIG_H__

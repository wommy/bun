#!/bin/bash
# Compile-validate a single JSC TU with -c.
WK=/tmp/claude-0/-home-user-bun/47781d5c-1fc9-57ba-ba88-3c8f1f56ef41/scratchpad/wk
PB=/root/.bun/build-cache/webkit-d71031a973e6f883-debug-asan
CXX=/tmp/llvm-install/LLVM-21.1.8-Linux-X64/bin/clang++
J=$WK/Source/JavaScriptCore
S=/tmp/claude-0/-home-user-bun/47781d5c-1fc9-57ba-ba88-3c8f1f56ef41/scratchpad/shadow

# Flattened shadow tree: every header name resolves to exactly ONE file
# (prebuilt generated headers, overlaid by the checkout's patched/pinned ones),
# so #pragma once is not defeated by the same header arriving via two paths.
INC="-I$S/jsc -I$S/inc"

exec $CXX -c \
  -DBUILDING_JSCONLY__ -DBUILDING_WEBKIT -DBUILDING_WITH_CMAKE -DHAVE_CONFIG_H \
  -DPAS_BMALLOC -D_GLIBCXX_ASSERTIONS -DASSERT_ENABLED=1 -DU_STATIC_IMPLEMENTATION=1 \
  $INC \
  -std=c++23 -stdlib=libstdc++ -fno-exceptions -fno-rtti -fcoroutines \
  -fno-c++-static-destructors -fno-strict-aliasing -fPIE \
  -fvisibility=hidden -fvisibility-inlines-hidden -march=nehalem \
  -Wno-nullability-completeness -Wno-psabi -Wno-misleading-indentation \
  -Wno-parentheses-equality -Wno-tautological-compare -Wno-unknown-warning-option \
  -Qunused-arguments -ferror-limit=0 \
  "$@"

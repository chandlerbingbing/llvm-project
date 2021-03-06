// RUN: mlir-translate -split-input-file -test-spirv-roundtrip %s | FileCheck %s

// Test branch with one block argument

spv.module "Logical" "GLSL450" {
  func @foo() -> () {
// CHECK:        %[[CST:.*]] = spv.constant 0
    %zero = spv.constant 0 : i32
// CHECK-NEXT:   spv.Branch ^bb1(%[[CST]] : i32)
    spv.Branch ^bb1(%zero : i32)
// CHECK-NEXT: ^bb1(%{{.*}}: i32):
  ^bb1(%arg0: i32):
   spv.Return
  }

  func @main() -> () {
    spv.Return
  }
  spv.EntryPoint "GLCompute" @main
} attributes {
  capabilities = ["Shader"]
}

// -----

// Test branch with multiple block arguments

spv.module "Logical" "GLSL450" {
  func @foo() -> () {
// CHECK:        %[[ZERO:.*]] = spv.constant 0
    %zero = spv.constant 0 : i32
// CHECK-NEXT:   %[[ONE:.*]] = spv.constant 1
    %one = spv.constant 1.0 : f32
// CHECK-NEXT:   spv.Branch ^bb1(%[[ZERO]], %[[ONE]] : i32, f32)
    spv.Branch ^bb1(%zero, %one : i32, f32)

// CHECK-NEXT: ^bb1(%{{.*}}: i32, %{{.*}}: f32):     // pred: ^bb0
  ^bb1(%arg0: i32, %arg1: f32):
   spv.Return
  }

  func @main() -> () {
    spv.Return
  }
  spv.EntryPoint "GLCompute" @main
} attributes {
  capabilities = ["Shader"]
}

// -----

// Test using block arguments within branch

spv.module "Logical" "GLSL450" {
  func @foo() -> () {
// CHECK:        %[[CST0:.*]] = spv.constant 0
    %zero = spv.constant 0 : i32
// CHECK-NEXT:   spv.Branch ^bb1(%[[CST0]] : i32)
    spv.Branch ^bb1(%zero : i32)

// CHECK-NEXT: ^bb1(%[[ARG:.*]]: i32):
  ^bb1(%arg0: i32):
// CHECK-NEXT:   %[[ADD:.*]] = spv.IAdd %[[ARG]], %[[ARG]] : i32
    %0 = spv.IAdd %arg0, %arg0 : i32
// CHECK-NEXT:   %[[CST1:.*]] = spv.constant 0
// CHECK-NEXT:   spv.Branch ^bb2(%[[CST1]], %[[ADD]] : i32, i32)
    spv.Branch ^bb2(%zero, %0 : i32, i32)

// CHECK-NEXT: ^bb2(%{{.*}}: i32, %{{.*}}: i32):
  ^bb2(%arg1: i32, %arg2: i32):
   spv.Return
  }

  func @main() -> () {
    spv.Return
  }
  spv.EntryPoint "GLCompute" @main
} attributes {
  capabilities = ["Shader"]
}

// -----

// Test block not following domination order

spv.module "Logical" "GLSL450" {
  func @foo() -> () {
// CHECK:        spv.Branch ^bb1
    spv.Branch ^bb1

// CHECK-NEXT: ^bb1:
// CHECK-NEXT:   %[[ZERO:.*]] = spv.constant 0
// CHECK-NEXT:   %[[ONE:.*]] = spv.constant 1
// CHECK-NEXT:   spv.Branch ^bb2(%[[ZERO]], %[[ONE]] : i32, f32)

// CHECK-NEXT: ^bb2(%{{.*}}: i32, %{{.*}}: f32):
  ^bb2(%arg0: i32, %arg1: f32):
// CHECK-NEXT:   spv.Return
   spv.Return

  // This block is reordered to follow domination order.
  ^bb1:
    %zero = spv.constant 0 : i32
    %one = spv.constant 1.0 : f32
    spv.Branch ^bb2(%zero, %one : i32, f32)
  }

  func @main() -> () {
    spv.Return
  }
  spv.EntryPoint "GLCompute" @main
} attributes {
  capabilities = ["Shader"]
}

// -----

// Test multiple predecessors

spv.module "Logical" "GLSL450" {
  func @foo() -> () {
    %var = spv.Variable : !spv.ptr<i32, Function>

// CHECK:      spv.selection
    spv.selection {
      %true = spv.constant true
// CHECK:        spv.BranchConditional %{{.*}}, ^bb1, ^bb2
      spv.BranchConditional %true, ^true, ^false

// CHECK-NEXT: ^bb1:
    ^true:
// CHECK-NEXT:   %[[ZERO:.*]] = spv.constant 0
      %zero = spv.constant 0 : i32
// CHECK-NEXT:   spv.Branch ^bb3(%[[ZERO]] : i32)
      spv.Branch ^phi(%zero: i32)

// CHECK-NEXT: ^bb2:
    ^false:
// CHECK-NEXT:   %[[ONE:.*]] = spv.constant 1
      %one = spv.constant 1 : i32
// CHECK-NEXT:   spv.Branch ^bb3(%[[ONE]] : i32)
      spv.Branch ^phi(%one: i32)

// CHECK-NEXT: ^bb3(%[[ARG:.*]]: i32):
    ^phi(%arg: i32):
// CHECK-NEXT:   spv.Store "Function" %{{.*}}, %[[ARG]] : i32
      spv.Store "Function" %var, %arg : i32
// CHECK-NEXT:   spv.Return
      spv.Return

// CHECK-NEXT: ^bb4:
    ^merge:
// CHECK-NEXT:   spv._merge
      spv._merge
    }
    spv.Return
  }

  func @main() -> () {
    spv.Return
  }
  spv.EntryPoint "GLCompute" @main
} attributes {
  capabilities = ["Shader"]
}

// -----

// Test nested loops with block arguments

spv.module "Logical" "GLSL450" {
  spv.globalVariable @__builtin_var_NumWorkgroups__ built_in("NumWorkgroups") : !spv.ptr<vector<3xi32>, Input>
  spv.globalVariable @__builtin_var_WorkgroupId__ built_in("WorkgroupId") : !spv.ptr<vector<3xi32>, Input>
  func @fmul_kernel() {
    %3 = spv.constant 12 : i32
    %4 = spv.constant 32 : i32
    %5 = spv.constant 4 : i32
    %6 = spv._address_of @__builtin_var_WorkgroupId__ : !spv.ptr<vector<3xi32>, Input>
    %7 = spv.Load "Input" %6 : vector<3xi32>
    %8 = spv.CompositeExtract %7[0 : i32] : vector<3xi32>
    %9 = spv._address_of @__builtin_var_WorkgroupId__ : !spv.ptr<vector<3xi32>, Input>
    %10 = spv.Load "Input" %9 : vector<3xi32>
    %11 = spv.CompositeExtract %10[1 : i32] : vector<3xi32>
    %18 = spv._address_of @__builtin_var_NumWorkgroups__ : !spv.ptr<vector<3xi32>, Input>
    %19 = spv.Load "Input" %18 : vector<3xi32>
    %20 = spv.CompositeExtract %19[0 : i32] : vector<3xi32>
    %21 = spv._address_of @__builtin_var_NumWorkgroups__ : !spv.ptr<vector<3xi32>, Input>
    %22 = spv.Load "Input" %21 : vector<3xi32>
    %23 = spv.CompositeExtract %22[1 : i32] : vector<3xi32>
    %30 = spv.IMul %11, %4 : i32
    %31 = spv.IMul %23, %4 : i32

// CHECK:   spv.Branch ^[[FN_BB:.*]](%{{.*}} : i32)
// CHECK: ^[[FN_BB]](%[[FN_BB_ARG:.*]]: i32):
// CHECK:   spv.loop {
    spv.loop {
// CHECK:     spv.Branch ^bb1(%[[FN_BB_ARG]] : i32)
      spv.Branch ^bb1(%30 : i32)
// CHECK:   ^[[LP1_HDR:.*]](%[[LP1_HDR_ARG:.*]]: i32):
    ^bb1(%32: i32):
// CHECK:     spv.SLessThan
      %33 = spv.SLessThan %32, %3 : i32
// CHECK:     spv.BranchConditional %{{.*}}, ^[[LP1_BDY:.*]], ^[[LP1_MG:.*]]
      spv.BranchConditional %33, ^bb2, ^bb3
// CHECK:   ^[[LP1_BDY]]:
    ^bb2:
// CHECK:     %[[MUL:.*]] = spv.IMul
      %34 = spv.IMul %8, %5 : i32
// CHECK:     spv.IMul
      %35 = spv.IMul %20, %5 : i32
// CHECK:     spv.Branch ^[[LP1_CNT:.*]](%[[MUL]] : i32)
// CHECK:   ^[[LP1_CNT]](%[[LP1_CNT_ARG:.*]]: i32):
// CHECK:     spv.loop {
      spv.loop {
// CHECK:       spv.Branch ^[[LP2_HDR:.*]](%[[LP1_CNT_ARG]] : i32)
        spv.Branch ^bb1(%34 : i32)
// CHECK:     ^[[LP2_HDR]](%[[LP2_HDR_ARG:.*]]: i32):
      ^bb1(%37: i32):
// CHECK:       spv.SLessThan %[[LP2_HDR_ARG]]
        %38 = spv.SLessThan %37, %5 : i32
// CHECK:       spv.BranchConditional %{{.*}}, ^[[LP2_BDY:.*]], ^[[LP2_MG:.*]]
        spv.BranchConditional %38, ^bb2, ^bb3
// CHECK:     ^[[LP2_BDY]]:
      ^bb2:
// CHECK:       %[[ADD1:.*]] = spv.IAdd
        %48 = spv.IAdd %37, %35 : i32
// CHECK:       spv.Branch ^[[LP2_HDR]](%[[ADD1]] : i32)
        spv.Branch ^bb1(%48 : i32)
// CHECK:     ^[[LP2_MG]]:
      ^bb3:
// CHECK:       spv._merge
        spv._merge
      }
// CHECK:     %[[ADD2:.*]] = spv.IAdd %[[LP1_HDR_ARG]]
      %36 = spv.IAdd %32, %31 : i32
// CHECK:     spv.Branch ^[[LP1_HDR]](%[[ADD2]] : i32)
      spv.Branch ^bb1(%36 : i32)
// CHECK:   ^[[LP1_MG]]:
    ^bb3:
// CHECK:     spv._merge
      spv._merge
    }
    spv.Return
  }

  spv.EntryPoint "GLCompute" @fmul_kernel, @__builtin_var_WorkgroupId__, @__builtin_var_NumWorkgroups__
  spv.ExecutionMode @fmul_kernel "LocalSize", 32, 1, 1
} attributes {capabilities = ["Shader"], extensions = ["SPV_KHR_storage_buffer_storage_class"]}

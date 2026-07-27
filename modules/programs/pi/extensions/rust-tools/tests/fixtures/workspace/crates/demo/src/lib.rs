pub fn compute(input: i32) -> i32 {
    debug_value(input)
}

#[inline(never)]
pub fn debug_value(input: i32) -> i32 {
    let decisive = input + 2;
    let observed = decisive;
    std::hint::black_box(observed)
}

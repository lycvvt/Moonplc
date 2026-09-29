///|
/// 测试 PLC 基础数据类型与地址解析
test "plc_value basic operations" {
  let v_true = PlcValue::Bool(true)
  let v_false = PlcValue::Bool(false)
  assert_eq(v_true.is_true(), true)
  assert_eq(v_false.is_true(), false)
  assert_eq(v_true.to_int(), 1)
  assert_eq(v_false.to_int(), 0)

  let i1 = PlcValue::Int(42)
  let i2 = PlcValue::Int(8)
  assert_eq(i1.add(i2).to_int(), 50)
  assert_eq(i1.sub(i2).to_int(), 34)
  assert_eq(i1.mul(i2).to_int(), 336)
  assert_eq(i1.div(i2).to_int(), 5)
  assert_eq(i1.modulo(i2).to_int(), 2)

  let t1 = PlcValue::Time(2500L)
  assert_eq(t1.to_string_repr(), "T#2500ms")
}

///|
test "parse_plc_address" {
  let addr_i = parse_plc_address("%IX0.1")
  match addr_i {
    Some(a) => {
      assert_eq(a.area, PlcArea::Input)
      assert_eq(a.size, PlcDataSize::Bit)
      assert_eq(a.byte_offset, 0)
      assert_eq(a.bit_offset, 1)
    }
    None => abort("expected Some")
  }

  let addr_q = parse_plc_address("%QX1.5")
  match addr_q {
    Some(a) => {
      assert_eq(a.area, PlcArea::Output)
      assert_eq(a.size, PlcDataSize::Bit)
      assert_eq(a.byte_offset, 1)
      assert_eq(a.bit_offset, 5)
    }
    None => abort("expected Some")
  }

  let addr_mw = parse_plc_address("%MW10")
  match addr_mw {
    Some(a) => {
      assert_eq(a.area, PlcArea::Memory)
      assert_eq(a.size, PlcDataSize::Word)
      assert_eq(a.byte_offset, 10)
    }
    None => abort("expected Some")
  }
}

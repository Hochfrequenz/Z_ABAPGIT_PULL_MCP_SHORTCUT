CLASS ltcl_list_fmt DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS count_fields
      IMPORTING iv_line TYPE string
      RETURNING VALUE(rv_count) TYPE i.
    METHODS header_three_repos     FOR TESTING.
    METHODS header_zero_repos      FOR TESTING.
    METHODS online_line            FOR TESTING.
    METHODS offline_line           FOR TESTING.
    METHODS empty_key_keeps_eight  FOR TESTING.
    METHODS empty_fields_kept      FOR TESTING.
ENDCLASS.


CLASS ltcl_list_fmt IMPLEMENTATION.

  METHOD count_fields.
    " Count the delimiters rather than SPLIT: SPLIT is not reliable about trailing
    " empty fields, which is exactly what is under test.
    rv_count = count( val = iv_line sub = '~' ) + 1.
  ENDMETHOD.

  METHOD header_three_repos.
    DATA(lv_line) = zcl_abapgit_mcp_list_fmt=>header( 3 ).
    cl_abap_unit_assert=>assert_equals( exp = `TOTAL~3~~~~~~` act = lv_line ).
    cl_abap_unit_assert=>assert_equals( exp = 8 act = count_fields( lv_line ) ).
  ENDMETHOD.

  METHOD header_zero_repos.
    cl_abap_unit_assert=>assert_equals( exp = `TOTAL~0~~~~~~`
                                        act = zcl_abapgit_mcp_list_fmt=>header( 0 ) ).
  ENDMETHOD.

  METHOD online_line.
    DATA(lv_line) = zcl_abapgit_mcp_list_fmt=>repo_line(
      iv_name = `REPO` iv_url = `https://example.com/o/r.git` iv_package = `$PKG`
      iv_branch = `refs/heads/main` iv_deserialized_at = `20260225120000.0000000`
      iv_deserialized_by = `DEV` iv_offline = abap_false iv_key = `000000000012` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `REPO~https://example.com/o/r.git~$PKG~refs/heads/main~20260225120000.0000000~DEV~~000000000012`
      act = lv_line ).
    cl_abap_unit_assert=>assert_equals( exp = 8 act = count_fields( lv_line ) ).
  ENDMETHOD.

  METHOD offline_line.
    DATA(lv_line) = zcl_abapgit_mcp_list_fmt=>repo_line(
      iv_name = `OFF` iv_url = `` iv_package = `$PKG` iv_branch = ``
      iv_deserialized_at = `` iv_deserialized_by = `` iv_offline = abap_true iv_key = `000000000007` ).
    cl_abap_unit_assert=>assert_equals( exp = `OFF~~$PKG~~~~X~000000000007` act = lv_line ).
    cl_abap_unit_assert=>assert_equals( exp = 8 act = count_fields( lv_line ) ).
  ENDMETHOD.

  METHOD empty_key_keeps_eight.
    DATA(lv_line) = zcl_abapgit_mcp_list_fmt=>repo_line(
      iv_name = `A` iv_url = `u` iv_package = `p` iv_branch = `b`
      iv_deserialized_at = `t` iv_deserialized_by = `d` iv_offline = abap_false iv_key = `` ).
    cl_abap_unit_assert=>assert_equals( exp = `A~u~p~b~t~d~~` act = lv_line ).
    cl_abap_unit_assert=>assert_equals( exp = 8 act = count_fields( lv_line ) ).
  ENDMETHOD.

  METHOD empty_fields_kept.
    DATA(lv_line) = zcl_abapgit_mcp_list_fmt=>repo_line(
      iv_name = `` iv_url = `` iv_package = `` iv_branch = ``
      iv_deserialized_at = `` iv_deserialized_by = `` iv_offline = abap_false iv_key = `000000000001` ).
    cl_abap_unit_assert=>assert_equals( exp = `~~~~~~~000000000001` act = lv_line ).
    cl_abap_unit_assert=>assert_equals( exp = 8 act = count_fields( lv_line ) ).
  ENDMETHOD.

ENDCLASS.

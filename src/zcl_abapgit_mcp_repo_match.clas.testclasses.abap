CLASS ltcl_repo_match DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS url_normalisation      FOR TESTING.
    METHODS unknown_repo_no_hit    FOR TESTING RAISING zcx_abapgit_exception.
    METHODS key_padded FOR TESTING.
    METHODS key_trimmed FOR TESTING.
    METHODS key_rejected FOR TESTING.
    METHODS selector_both FOR TESTING.
    METHODS selector_neither FOR TESTING.
    METHODS selector_single FOR TESTING.
    METHODS selector_invalid_key FOR TESTING.
    METHODS select_hit FOR TESTING.
    METHODS select_miss FOR TESTING.
    METHODS select_offline_excl FOR TESTING.
    METHODS select_no_partial FOR TESTING.
ENDCLASS.


CLASS ltcl_repo_match IMPLEMENTATION.

  METHOD url_normalisation.
    DATA(lv_expected) = `HTTPS://GITHUB.COM/EXAMPLE/REPO`.
    cl_abap_unit_assert=>assert_equals(
      exp = lv_expected act = zcl_abapgit_mcp_repo_match=>normalise_url( `https://github.com/example/repo` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = lv_expected act = zcl_abapgit_mcp_repo_match=>normalise_url( `https://github.com/example/repo.git` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = lv_expected act = zcl_abapgit_mcp_repo_match=>normalise_url( `https://github.com/Example/Repo/` ) ).
  ENDMETHOD.


  METHOD unknown_repo_no_hit.
    cl_abap_unit_assert=>assert_initial(
      zcl_abapgit_mcp_repo_match=>find_online_repos( `https://example.invalid/no/such/repo.git` ) ).
  ENDMETHOD.

  METHOD key_padded.
    cl_abap_unit_assert=>assert_equals( exp = `000000000012` act = zcl_abapgit_mcp_repo_match=>normalise_key( `12` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `000000000000` act = zcl_abapgit_mcp_repo_match=>normalise_key( `0` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `123456789012` act = zcl_abapgit_mcp_repo_match=>normalise_key( `123456789012` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `000000000012` act = zcl_abapgit_mcp_repo_match=>normalise_key( `000000000012` ) ).
  ENDMETHOD.


  METHOD key_trimmed.
    cl_abap_unit_assert=>assert_equals( exp = `000000000012` act = zcl_abapgit_mcp_repo_match=>normalise_key( `  12  ` ) ).
  ENDMETHOD.


  METHOD key_rejected.
    " an empty result means: rejected (never a truncated or partial key)
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_repo_match=>normalise_key( `abc` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_repo_match=>normalise_key( `1234567890123` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_repo_match=>normalise_key( `12 34` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_repo_match=>normalise_key( `-12` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_repo_match=>normalise_key( `12a` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_repo_match=>normalise_key( `` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_repo_match=>normalise_key( `   ` ) ).
  ENDMETHOD.


  METHOD selector_both.
    " even if they agree
    cl_abap_unit_assert=>assert_equals(
      exp = `Use either P_REPO or P_KEY, not both`
      act = zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = `12` iv_key = `12` ) ).
    " both wins over an invalid key
    cl_abap_unit_assert=>assert_equals(
      exp = `Use either P_REPO or P_KEY, not both`
      act = zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = `x` iv_key = `abc` ) ).
  ENDMETHOD.


  METHOD selector_neither.
    cl_abap_unit_assert=>assert_equals(
      exp = `P_REPO or P_KEY is required for PULL action`
      act = zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = `` iv_key = `` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `P_REPO or P_KEY is required for PULL action`
      act = zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = `` iv_key = `   ` ) ).
  ENDMETHOD.


  METHOD selector_single.
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = `my_repo` iv_key = `` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = `` iv_key = `12` ) ).
    " an all-digit name stays a valid P_REPO
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = `2024` iv_key = `` ) ).
  ENDMETHOD.


  METHOD selector_invalid_key.
    cl_abap_unit_assert=>assert_equals(
      exp = `Invalid P_KEY: abc (digits only, max 12)`
      act = zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = `` iv_key = `abc` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `Invalid P_KEY: 1234567890123 (digits only, max 12)`
      act = zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = `` iv_key = `1234567890123` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `Invalid P_KEY: 12 34 (digits only, max 12)`
      act = zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = `` iv_key = `12 34` ) ).
    " a long value is cut, the hint stays
    cl_abap_unit_assert=>assert_equals(
      exp = `Invalid P_KEY: 12345678901... (digits only, max 12)`
      act = zcl_abapgit_mcp_repo_match=>check_selector( iv_repo = `` iv_key = `1234567890123456789` ) ).
  ENDMETHOD.


  METHOD select_hit.
    DATA(lt_candidates) = VALUE zcl_abapgit_mcp_repo_match=>ty_candidates(
      ( key = `000000000001` offline = abap_false )
      ( key = `000000000002` offline = abap_false )
      ( key = `000000000003` offline = abap_false ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE zcl_abapgit_mcp_repo_match=>ty_indexes( ( 2 ) )
      act = zcl_abapgit_mcp_repo_match=>select_by_key( it_candidates = lt_candidates iv_key = `000000000002` ) ).
  ENDMETHOD.


  METHOD select_miss.
    DATA(lt_candidates) = VALUE zcl_abapgit_mcp_repo_match=>ty_candidates(
      ( key = `000000000001` offline = abap_false ) ).
    cl_abap_unit_assert=>assert_initial(
      zcl_abapgit_mcp_repo_match=>select_by_key( it_candidates = lt_candidates iv_key = `000000000009` ) ).
    cl_abap_unit_assert=>assert_initial(
      zcl_abapgit_mcp_repo_match=>select_by_key( it_candidates = VALUE #( ) iv_key = `000000000001` ) ).
    cl_abap_unit_assert=>assert_initial(
      zcl_abapgit_mcp_repo_match=>select_by_key( it_candidates = lt_candidates iv_key = `` ) ).
  ENDMETHOD.


  METHOD select_offline_excl.
    DATA(lt_candidates) = VALUE zcl_abapgit_mcp_repo_match=>ty_candidates(
      ( key = `000000000001` offline = abap_true )
      ( key = `000000000002` offline = abap_false ) ).
    cl_abap_unit_assert=>assert_initial(
      zcl_abapgit_mcp_repo_match=>select_by_key( it_candidates = lt_candidates iv_key = `000000000001` ) ).
  ENDMETHOD.


  METHOD select_no_partial.
    " no padding, no prefix match: only the exact key
    DATA(lt_candidates) = VALUE zcl_abapgit_mcp_repo_match=>ty_candidates(
      ( key = `000000000012` offline = abap_false ) ).
    cl_abap_unit_assert=>assert_initial(
      zcl_abapgit_mcp_repo_match=>select_by_key( it_candidates = lt_candidates iv_key = `12` ) ).
  ENDMETHOD.

ENDCLASS.

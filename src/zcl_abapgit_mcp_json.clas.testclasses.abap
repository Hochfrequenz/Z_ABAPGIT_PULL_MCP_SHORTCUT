CLASS ltcl_json DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS repos_use_contract_names     FOR TESTING.
    METHODS offline_is_json_boolean      FOR TESTING.
    METHODS pull_request_minimal         FOR TESTING.
    METHODS pull_request_any_order       FOR TESTING.
    METHODS push_request_dry_run         FOR TESTING.
    METHODS unknown_member_is_bad        FOR TESTING.
    METHODS malformed_json_is_bad        FOR TESTING.
    METHODS empty_body_is_bad            FOR TESTING.
    METHODS pull_result_with_files       FOR TESTING.
    METHODS push_result_commit_optional  FOR TESTING.
    METHODS error_with_details           FOR TESTING.

    METHODS assert_bad_request
      IMPORTING
        iv_json TYPE string.
ENDCLASS.


CLASS ltcl_json IMPLEMENTATION.

  METHOD repos_use_contract_names.
    cl_abap_unit_assert=>assert_equals(
      exp = `{"repos":[{"key":"000000000001","name":"example","url":"https://github.com/example/repo",` &&
            `"package":"ZEXAMPLE","branch":"refs/heads/main","offline":false,` &&
            `"deserialized_at":"2026-10-06T07:42:34Z","deserialized_by":"DEVUSER"}]}`
      act = zcl_abapgit_mcp_json=>repos_to_json( VALUE #(
              ( key             = `000000000001`
                name            = `example`
                url             = `https://github.com/example/repo`
                package         = `ZEXAMPLE`
                branch          = `refs/heads/main`
                offline         = abap_false
                deserialized_at = `2026-10-06T07:42:34Z`
                deserialized_by = `DEVUSER` ) ) ) ).
  ENDMETHOD.


  METHOD offline_is_json_boolean.
    DATA(lv_json) = zcl_abapgit_mcp_json=>repos_to_json( VALUE #( ( offline = abap_true ) ) ).
    cl_abap_unit_assert=>assert_char_cp( exp = '*"offline":true*' act = lv_json ).
  ENDMETHOD.


  METHOD pull_request_minimal.
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE zif_abapgit_mcp_sync=>ty_pull_request( repo = `example` )
      act = zcl_abapgit_mcp_json=>pull_request_from_json( `{"repo":"example"}` ) ).
  ENDMETHOD.


  METHOD pull_request_any_order.
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE zif_abapgit_mcp_sync=>ty_pull_request(
              repo      = `example`
              transport = `<request>`
              confirm   = VALUE #( ( obj_type = `CLAS` obj_name = `ZCL_EXAMPLE` action = `overwrite` ) ) )
      act = zcl_abapgit_mcp_json=>pull_request_from_json(
              `{"confirm":[{"action":"overwrite","obj_name":"ZCL_EXAMPLE","obj_type":"CLAS"}],` &&
              `"transport":"<request>","repo":"example"}` ) ).
  ENDMETHOD.


  METHOD push_request_dry_run.
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE zif_abapgit_mcp_sync=>ty_push_request(
              repo    = `example`
              objects = VALUE #( ( obj_type = `PROG` obj_name = `ZEXAMPLE` ) )
              message = `msg`
              dry_run = abap_true )
      act = zcl_abapgit_mcp_json=>push_request_from_json(
              `{"repo":"example","objects":[{"obj_type":"PROG","obj_name":"ZEXAMPLE"}],"message":"msg","dry_run":true}` ) ).

    cl_abap_unit_assert=>assert_false( zcl_abapgit_mcp_json=>push_request_from_json(
      `{"repo":"example","objects":[],"message":"msg","dry_run":false}` )-dry_run ).
    cl_abap_unit_assert=>assert_false( zcl_abapgit_mcp_json=>push_request_from_json(
      `{"repo":"example","message":"msg"}` )-dry_run ).
  ENDMETHOD.


  METHOD assert_bad_request.
    DATA lx_error TYPE REF TO zcx_abapgit_mcp_sync.

    TRY.
        zcl_abapgit_mcp_json=>pull_request_from_json( iv_json ).
      CATCH zcx_abapgit_mcp_sync INTO lx_error.
    ENDTRY.
    cl_abap_unit_assert=>assert_bound( act = lx_error msg = iv_json ).
    cl_abap_unit_assert=>assert_equals( exp = zif_abapgit_mcp_sync=>c_error-bad_request
                                        act = lx_error->mv_code
                                        msg = iv_json ).
  ENDMETHOD.


  METHOD unknown_member_is_bad.
    assert_bad_request( `{"repo":"example","force":true}` ).
  ENDMETHOD.


  METHOD malformed_json_is_bad.
    assert_bad_request( `{"repo":` ).
  ENDMETHOD.


  METHOD empty_body_is_bad.
    assert_bad_request( `` ).
  ENDMETHOD.


  METHOD pull_result_with_files.
    cl_abap_unit_assert=>assert_equals(
      exp = `{"status":"needs_confirmation","repo":{"name":"example","url":"u","package":"ZEXAMPLE"},` &&
            `"confirmations_required":[{"obj_type":"CLAS","obj_name":"ZCL_EXAMPLE","action":"delete",` &&
            `"text":"Delete local object","files":[{"path":"/src/","filename":"zcl_example.clas.abap","state":"MD"}]}],` &&
            `"log":[]}`
      act = zcl_abapgit_mcp_json=>pull_result_to_json( VALUE #(
              status = zif_abapgit_mcp_sync=>c_status-needs_confirmation
              repo   = VALUE #( name = `example` url = `u` package = `ZEXAMPLE` )
              confirmations_required = VALUE #(
                ( obj_type = `CLAS` obj_name = `ZCL_EXAMPLE` action = `delete` text = `Delete local object`
                  files = VALUE #( ( path = `/src/` filename = `zcl_example.clas.abap` state = `MD` ) ) ) ) ) ) ).
  ENDMETHOD.


  METHOD push_result_commit_optional.
    cl_abap_unit_assert=>assert_equals(
      exp = `{"status":"nothing_to_push","author":{"name":"n","email":"e"},"files":[]}`
      act = zcl_abapgit_mcp_json=>push_result_to_json( VALUE #(
              status = zif_abapgit_mcp_sync=>c_status-nothing_to_push
              author = VALUE #( name = `n` email = `e` ) ) ) ).

    cl_abap_unit_assert=>assert_char_cp(
      exp = '*"commit":"0123abc"*'
      act = zcl_abapgit_mcp_json=>push_result_to_json( VALUE #( status = zif_abapgit_mcp_sync=>c_status-pushed
                                                               commit = `0123abc` ) ) ).
  ENDMETHOD.


  METHOD error_with_details.
    cl_abap_unit_assert=>assert_equals(
      exp = `{"code":"REMOTE_CHANGED","message":"pull first","details":["/src/zexample.prog.abap _M"]}`
      act = zcl_abapgit_mcp_json=>error_to_json( VALUE #( code    = `REMOTE_CHANGED`
                                                         message = `pull first`
                                                         details = VALUE #( ( `/src/zexample.prog.abap _M` ) ) ) ) ).
  ENDMETHOD.

ENDCLASS.

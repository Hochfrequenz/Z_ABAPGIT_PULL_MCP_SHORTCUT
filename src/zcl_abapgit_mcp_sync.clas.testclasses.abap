CLASS ltcl_sync DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS iso_timestamp              FOR TESTING.
    METHODS pull_without_repo_is_bad   FOR TESTING.
    METHODS push_without_objects_is_bad FOR TESTING.
    METHODS unknown_repo_is_not_found  FOR TESTING.
    METHODS empty_object_name_is_bad   FOR TESTING.
    METHODS empty_confirm_action_is_bad FOR TESTING.

    METHODS assert_code
      IMPORTING
        ix_error TYPE REF TO zcx_abapgit_mcp_sync
        iv_code  TYPE string.
ENDCLASS.


CLASS ltcl_sync IMPLEMENTATION.

  METHOD assert_code.
    cl_abap_unit_assert=>assert_bound( ix_error ).
    cl_abap_unit_assert=>assert_equals( exp = iv_code act = ix_error->mv_code ).
  ENDMETHOD.



  METHOD iso_timestamp.
    DATA lv_timestamp TYPE timestampl VALUE '20261006074234.1234567'.

    cl_abap_unit_assert=>assert_equals( exp = `2026-10-06T07:42:34Z`
                                        act = zcl_abapgit_mcp_sync=>to_iso_timestamp( lv_timestamp ) ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_mcp_sync=>to_iso_timestamp( 0 ) ).
  ENDMETHOD.


  METHOD pull_without_repo_is_bad.
    DATA lx_error TYPE REF TO zcx_abapgit_mcp_sync.

    TRY.
        NEW zcl_abapgit_mcp_sync( )->pull( VALUE #( ) ).
      CATCH zcx_abapgit_mcp_sync INTO lx_error.
    ENDTRY.
    assert_code( ix_error = lx_error iv_code = zif_abapgit_mcp_sync=>c_error-bad_request ).
  ENDMETHOD.


  METHOD push_without_objects_is_bad.
    DATA lx_error TYPE REF TO zcx_abapgit_mcp_sync.

    TRY.
        NEW zcl_abapgit_mcp_sync( )->push( VALUE #( repo = `example` message = `msg` ) ).
      CATCH zcx_abapgit_mcp_sync INTO lx_error.
    ENDTRY.
    assert_code( ix_error = lx_error iv_code = zif_abapgit_mcp_sync=>c_error-bad_request ).
  ENDMETHOD.


  METHOD unknown_repo_is_not_found.
    DATA lx_error TYPE REF TO zcx_abapgit_mcp_sync.

    " Resolution happens before any Git host is contacted
    TRY.
        NEW zcl_abapgit_mcp_sync( )->pull( VALUE #( repo = `https://example.invalid/no/such/repo.git` ) ).
      CATCH zcx_abapgit_mcp_sync INTO lx_error.
    ENDTRY.
    assert_code( ix_error = lx_error iv_code = zif_abapgit_mcp_sync=>c_error-repo_not_found ).
    cl_abap_unit_assert=>assert_equals( exp = 404 act = lx_error->http_status( ) ).
  ENDMETHOD.


  METHOD empty_object_name_is_bad.
    DATA lx_error TYPE REF TO zcx_abapgit_mcp_sync.

    " Rejected before the repository is resolved or any Git host is contacted
    TRY.
        NEW zcl_abapgit_mcp_sync( )->push( VALUE #( repo    = `https://example.invalid/no/such/repo.git`
                                                    message = `msg`
                                                    objects = VALUE #( ( obj_type = `PROG` obj_name = `` ) ) ) ).
      CATCH zcx_abapgit_mcp_sync INTO lx_error.
    ENDTRY.
    assert_code( ix_error = lx_error iv_code = zif_abapgit_mcp_sync=>c_error-bad_request ).
  ENDMETHOD.


  METHOD empty_confirm_action_is_bad.
    DATA lx_error TYPE REF TO zcx_abapgit_mcp_sync.

    TRY.
        NEW zcl_abapgit_mcp_sync( )->pull( VALUE #( repo    = `https://example.invalid/no/such/repo.git`
                                                    confirm = VALUE #( ( obj_type = `CLAS` obj_name = `ZCL_EXAMPLE` ) ) ) ).
      CATCH zcx_abapgit_mcp_sync INTO lx_error.
    ENDTRY.
    assert_code( ix_error = lx_error iv_code = zif_abapgit_mcp_sync=>c_error-bad_request ).
  ENDMETHOD.

ENDCLASS.

CLASS ltcl_git_auth DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS push_without_destination_fails FOR TESTING.
    METHODS default_destination_is_per_usr FOR TESTING.
    METHODS host_of_url                    FOR TESTING.
ENDCLASS.


CLASS ltcl_git_auth IMPLEMENTATION.

  METHOD push_without_destination_fails.
    " No network: the destination is looked up before any request is sent
    DATA(lo_cut) = NEW zcl_abapgit_mcp_git_auth( iv_destination = 'ZGIT_UNIT_TEST_NONEXIST' ).

    TRY.
        lo_cut->preflight( iv_url                  = `https://github.com/example/repo.git`
                           iv_service              = zcl_abapgit_mcp_git_auth=>c_service-receive_pack
                           iv_credentials_required = abap_true ).
        cl_abap_unit_assert=>fail( 'CREDENTIALS_MISSING expected' ).
      CATCH zcx_abapgit_mcp_sync INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( exp = zif_abapgit_mcp_sync=>c_error-credentials_missing
                                            act = lx_error->mv_code ).
        cl_abap_unit_assert=>assert_equals( exp = 422 act = lx_error->http_status( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD default_destination_is_per_usr.
    cl_abap_unit_assert=>assert_equals( exp = |ZGIT_{ sy-uname }|
                                        act = NEW zcl_abapgit_mcp_git_auth( )->get_destination( ) ).
  ENDMETHOD.


  METHOD host_of_url.
    cl_abap_unit_assert=>assert_equals( exp = `github.com`
                                        act = zcl_abapgit_mcp_git_auth=>url_host( `https://github.com/a/b.git` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `github.com`
                                        act = zcl_abapgit_mcp_git_auth=>url_host( `https://GitHub.com:443/a/b` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `example.org`
                                        act = zcl_abapgit_mcp_git_auth=>url_host( `http://example.org` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `https://github.com`
                                        act = zcl_abapgit_mcp_git_auth=>url_base( `https://github.com/a/b.git` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `/a/b.git`
                                        act = zcl_abapgit_mcp_git_auth=>url_path( `https://github.com/a/b.git` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `/a/b`
                                        act = zcl_abapgit_mcp_git_auth=>url_path( `https://github.com/a/b/` ) ).
  ENDMETHOD.

ENDCLASS.

"! <p class="shorttext synchronized">abapGit sync: GET /sap/bc/adt/abapgitsync/repos</p>
CLASS zcl_abapgit_mcp_adt_repos DEFINITION
  PUBLIC
  INHERITING FROM zcl_abapgit_mcp_adt_res
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS get REDEFINITION.

ENDCLASS.



CLASS zcl_abapgit_mcp_adt_repos IMPLEMENTATION.


  METHOD get.

    TRY.
        respond( io_response = response
                 iv_status   = cl_rest_status_code=>gc_success_ok
                 iv_json     = zcl_abapgit_mcp_json=>repos_to_json( NEW zcl_abapgit_mcp_sync( )->list( ) ) ).
      CATCH cx_root INTO DATA(lx_error).
        respond_error( io_response = response
                       ix_error    = lx_error ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.

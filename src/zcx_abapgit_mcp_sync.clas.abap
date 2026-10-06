"! <p class="shorttext synchronized">abapGit sync: error with contract code</p>
"! Carries one of the error codes of the endpoint contract
"! (ZIF_ABAPGIT_MCP_SYNC=&gt;C_ERROR) plus the HTTP status it is answered with.
CLASS zcx_abapgit_mcp_sync DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA mv_code TYPE string READ-ONLY.
    DATA mv_text TYPE string READ-ONLY.
    DATA mt_details TYPE string_table READ-ONLY.

    METHODS constructor
      IMPORTING
        textid     LIKE textid OPTIONAL
        previous   LIKE previous OPTIONAL
        iv_code    TYPE string OPTIONAL
        iv_text    TYPE string OPTIONAL
        it_details TYPE string_table OPTIONAL.

    CLASS-METHODS raise
      IMPORTING
        iv_code     TYPE string
        iv_text     TYPE string
        it_details  TYPE string_table OPTIONAL
        ix_previous TYPE REF TO cx_root OPTIONAL
      RAISING
        zcx_abapgit_mcp_sync.

    "! HTTP status of a contract error code. The endpoints never answer 401
    "! or 403, because ADT clients re-authenticate and replay the POST.
    CLASS-METHODS http_status_of
      IMPORTING
        iv_code          TYPE string
      RETURNING
        VALUE(rv_status) TYPE i.

    METHODS http_status
      RETURNING
        VALUE(rv_status) TYPE i.

    METHODS to_error
      RETURNING
        VALUE(rs_error) TYPE zif_abapgit_mcp_sync=>ty_error.

    METHODS if_message~get_text REDEFINITION.

ENDCLASS.



CLASS ZCX_ABAPGIT_MCP_SYNC IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    super->constructor( textid   = textid
                        previous = previous ).
    mv_code    = iv_code.
    mv_text    = iv_text.
    mt_details = it_details.

  ENDMETHOD.


  METHOD http_status.

    rv_status = http_status_of( mv_code ).

  ENDMETHOD.


  METHOD http_status_of.

    rv_status = SWITCH #( iv_code
      WHEN zif_abapgit_mcp_sync=>c_error-repo_not_found       THEN 404
      WHEN zif_abapgit_mcp_sync=>c_error-repo_ambiguous       THEN 409
      WHEN zif_abapgit_mcp_sync=>c_error-remote_changed       THEN 409
      WHEN zif_abapgit_mcp_sync=>c_error-object_not_in_repo   THEN 422
      WHEN zif_abapgit_mcp_sync=>c_error-credentials_missing  THEN 422
      WHEN zif_abapgit_mcp_sync=>c_error-credentials_rejected THEN 422
      WHEN zif_abapgit_mcp_sync=>c_error-transport_required   THEN 422
      WHEN zif_abapgit_mcp_sync=>c_error-no_modifiable_task   THEN 422
      WHEN zif_abapgit_mcp_sync=>c_error-requirements_not_met THEN 422
      WHEN zif_abapgit_mcp_sync=>c_error-git_error            THEN 424
      WHEN zif_abapgit_mcp_sync=>c_error-bad_request          THEN 400
      ELSE 500 ).

  ENDMETHOD.


  METHOD if_message~get_text.

    result = mv_text.
    IF result IS INITIAL AND previous IS BOUND.
      result = previous->get_text( ).
    ENDIF.

  ENDMETHOD.


  METHOD raise.

    RAISE EXCEPTION TYPE zcx_abapgit_mcp_sync
      EXPORTING
        previous   = ix_previous
        iv_code    = iv_code
        iv_text    = iv_text
        it_details = it_details.

  ENDMETHOD.


  METHOD to_error.

    rs_error = VALUE #( code    = COND #( WHEN mv_code IS INITIAL
                                          THEN zif_abapgit_mcp_sync=>c_error-internal
                                          ELSE mv_code )
                        message = get_text( )
                        details = mt_details ).

  ENDMETHOD.
ENDCLASS.

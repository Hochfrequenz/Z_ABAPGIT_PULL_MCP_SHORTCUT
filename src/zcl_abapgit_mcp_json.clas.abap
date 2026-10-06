"! <p class="shorttext synchronized">abapGit sync: JSON bodies of the ADT endpoints</p>
"! Reads and writes the JSON contract through the Simple Transformations
"! ZABAPGIT_MCP_*. Plain CALL TRANSFORMATION id would write upper-case names,
"! a root element and abap_bool as "X".
CLASS zcl_abapgit_mcp_json DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS repos_to_json
      IMPORTING
        it_repos       TYPE zif_abapgit_mcp_sync=>ty_repos
      RETURNING
        VALUE(rv_json) TYPE string.

    CLASS-METHODS pull_result_to_json
      IMPORTING
        is_result      TYPE zif_abapgit_mcp_sync=>ty_pull_result
      RETURNING
        VALUE(rv_json) TYPE string.

    CLASS-METHODS push_result_to_json
      IMPORTING
        is_result      TYPE zif_abapgit_mcp_sync=>ty_push_result
      RETURNING
        VALUE(rv_json) TYPE string.

    CLASS-METHODS error_to_json
      IMPORTING
        is_error       TYPE zif_abapgit_mcp_sync=>ty_error
      RETURNING
        VALUE(rv_json) TYPE string.

    CLASS-METHODS pull_request_from_json
      IMPORTING
        iv_json           TYPE string
      RETURNING
        VALUE(rs_request) TYPE zif_abapgit_mcp_sync=>ty_pull_request
      RAISING
        zcx_abapgit_mcp_sync.

    CLASS-METHODS push_request_from_json
      IMPORTING
        iv_json           TYPE string
      RETURNING
        VALUE(rs_request) TYPE zif_abapgit_mcp_sync=>ty_push_request
      RAISING
        zcx_abapgit_mcp_sync.

  PRIVATE SECTION.

    CLASS-METHODS new_writer
      RETURNING
        VALUE(ro_writer) TYPE REF TO cl_sxml_string_writer.

    CLASS-METHODS output
      IMPORTING
        io_writer      TYPE REF TO cl_sxml_string_writer
      RETURNING
        VALUE(rv_json) TYPE string.

    CLASS-METHODS new_reader
      IMPORTING
        iv_json          TYPE string
      RETURNING
        VALUE(ri_reader) TYPE REF TO if_sxml_reader
      RAISING
        zcx_abapgit_mcp_sync.

    CLASS-METHODS raise_bad_request
      IMPORTING
        ix_error TYPE REF TO cx_root
      RAISING
        zcx_abapgit_mcp_sync.

ENDCLASS.



CLASS zcl_abapgit_mcp_json IMPLEMENTATION.


  METHOD repos_to_json.

    DATA(lo_writer) = new_writer( ).
    CALL TRANSFORMATION zabapgit_mcp_repos SOURCE repos = it_repos RESULT XML lo_writer.
    rv_json = output( lo_writer ).

  ENDMETHOD.


  METHOD pull_result_to_json.

    DATA(lo_writer) = new_writer( ).
    CALL TRANSFORMATION zabapgit_mcp_pull_res SOURCE result = is_result RESULT XML lo_writer.
    rv_json = output( lo_writer ).

  ENDMETHOD.


  METHOD push_result_to_json.

    DATA(lo_writer) = new_writer( ).
    CALL TRANSFORMATION zabapgit_mcp_push_res SOURCE result = is_result RESULT XML lo_writer.
    rv_json = output( lo_writer ).

  ENDMETHOD.


  METHOD error_to_json.

    DATA(lo_writer) = new_writer( ).
    CALL TRANSFORMATION zabapgit_mcp_error SOURCE error = is_error RESULT XML lo_writer.
    rv_json = output( lo_writer ).

  ENDMETHOD.


  METHOD pull_request_from_json.

    DATA(li_reader) = new_reader( iv_json ).
    TRY.
        CALL TRANSFORMATION zabapgit_mcp_pull_req SOURCE XML li_reader RESULT request = rs_request.
      CATCH cx_transformation_error cx_sxml_error INTO DATA(lx_error).
        raise_bad_request( lx_error ).
    ENDTRY.

  ENDMETHOD.


  METHOD push_request_from_json.

    DATA(li_reader) = new_reader( iv_json ).
    TRY.
        CALL TRANSFORMATION zabapgit_mcp_push_req SOURCE XML li_reader RESULT request = rs_request.
      CATCH cx_transformation_error cx_sxml_error INTO DATA(lx_error).
        raise_bad_request( lx_error ).
    ENDTRY.

  ENDMETHOD.


  METHOD new_writer.

    ro_writer = CAST cl_sxml_string_writer( cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ) ).

  ENDMETHOD.


  METHOD output.

    rv_json = cl_abap_codepage=>convert_from( io_writer->get_output( ) ).

  ENDMETHOD.


  METHOD new_reader.

    IF iv_json IS INITIAL.
      zcx_abapgit_mcp_sync=>raise( iv_code = zif_abapgit_mcp_sync=>c_error-bad_request
                                   iv_text = `A JSON request body is required` ).
    ENDIF.
    ri_reader = cl_sxml_string_reader=>create( cl_abap_codepage=>convert_to( iv_json ) ).

  ENDMETHOD.


  METHOD raise_bad_request.

    zcx_abapgit_mcp_sync=>raise( iv_code     = zif_abapgit_mcp_sync=>c_error-bad_request
                                 iv_text     = |Request body does not match the contract: { ix_error->get_text( ) }|
                                 ix_previous = ix_error ).

  ENDMETHOD.

ENDCLASS.

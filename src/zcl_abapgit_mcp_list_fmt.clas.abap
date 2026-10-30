"! <p class="shorttext synchronized">abapGit sync: line layout of the LIST output</p>
"! Pure formatting for the report Z_ABAPGIT_PULL_MCP_SHORTCUT (P_ACTION = LIST).
"! No database and no abapGit dependency, so it is unit-testable and the report
"! keeps compiling on every abapGit release.
"!
"! Line layout, fields separated by a tilde:
"! name~url~package~branch~deserialized_at~deserialized_by~offline~key
"! Fields may be appended in future; readers must ignore unknown trailing fields.
CLASS zcl_abapgit_mcp_list_fmt DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Header line: TOTAL~n followed by six tildes, so it has the same
    "! eight fields as a repository line.
    CLASS-METHODS header
      IMPORTING
        iv_total       TYPE i
      RETURNING
        VALUE(rv_line) TYPE string.

    "! One repository line with eight fields. Empty fields are kept; the
    "! offline flag is always present (X or empty), so the key is always
    "! field 8. The key is digits only (abapGit repository key).
    CLASS-METHODS repo_line
      IMPORTING
        iv_name            TYPE csequence
        iv_url             TYPE csequence
        iv_package         TYPE csequence
        iv_branch          TYPE csequence
        iv_deserialized_at TYPE csequence
        iv_deserialized_by TYPE csequence
        iv_offline         TYPE abap_bool
        iv_key             TYPE csequence
      RETURNING
        VALUE(rv_line)     TYPE string.

ENDCLASS.



CLASS zcl_abapgit_mcp_list_fmt IMPLEMENTATION.


  METHOD header.

    rv_line = |TOTAL~{ iv_total }~~~~~~|.

  ENDMETHOD.


  METHOD repo_line.

    DATA(lv_offline_flag) = COND string( WHEN iv_offline = abap_true THEN 'X' ELSE '' ).

    rv_line = |{ iv_name }~{ iv_url }~{ iv_package }~{ iv_branch }~{ iv_deserialized_at }~| &&
              |{ iv_deserialized_by }~{ lv_offline_flag }~{ iv_key }|.

  ENDMETHOD.
ENDCLASS.

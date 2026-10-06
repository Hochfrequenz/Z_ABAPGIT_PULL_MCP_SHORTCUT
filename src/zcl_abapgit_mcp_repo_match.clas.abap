"! <p class="shorttext synchronized">abapGit sync: exact repository matching</p>
"! Shared by the report Z_ABAPGIT_PULL_MCP_SHORTCUT and the ADT endpoints.
"! Kept separate from ZCL_ABAPGIT_MCP_SYNC on purpose: it depends only on the
"! abapGit repository service, so the report keeps compiling even where other
"! abapGit APIs used by the endpoints move between abapGit versions.
CLASS zcl_abapgit_mcp_repo_match DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES ty_online_repos TYPE STANDARD TABLE OF REF TO zcl_abapgit_repo_online WITH EMPTY KEY.

    "! Online repositories whose name (case-insensitive) or normalised URL
    "! equals iv_repo exactly. Never a substring match.
    CLASS-METHODS find_online_repos
      IMPORTING
        iv_repo        TYPE csequence
      RETURNING
        VALUE(rt_hits) TYPE ty_online_repos
      RAISING
        zcx_abapgit_exception.

    "! Upper case, without a trailing slash and a .git suffix
    CLASS-METHODS normalise_url
      IMPORTING
        iv_url        TYPE csequence
      RETURNING
        VALUE(rv_url) TYPE string.

ENDCLASS.



CLASS ZCL_ABAPGIT_MCP_REPO_MATCH IMPLEMENTATION.


  METHOD find_online_repos.

    DATA lo_online TYPE REF TO zcl_abapgit_repo_online.

    " Two comparands on purpose: the URL is normalised (a trailing slash and a
    " .git suffix are noise there), the name is only uppercased, because for a
    " name those characters are real.
    DATA(lv_want_url)  = normalise_url( iv_repo ).
    DATA(lv_want_name) = to_upper( iv_repo ).

    LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( iv_offline = abap_false ) INTO DATA(li_repo).
      " Defensive: list( iv_offline = abap_false ) should yield only online
      " repositories, but an unguarded cast would abort the whole search on
      " one bad entry and make a matching repository later in the list
      " unreachable.
      TRY.
          lo_online ?= li_repo.
        CATCH cx_sy_move_cast_error.
          CONTINUE.
      ENDTRY.

      " URL as well as name: a URL is unique, whereas get_name( ) falls back to
      " a URL-derived value when the stored name is blank. Case-insensitive on
      " both, because the earlier CS match was too.
      IF to_upper( lo_online->get_name( ) ) = lv_want_name
         OR normalise_url( lo_online->get_url( ) ) = lv_want_url.
        APPEND lo_online TO rt_hits.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD normalise_url.

    rv_url = to_upper( iv_url ).
    IF rv_url CP '*/'.
      rv_url = substring( val = rv_url len = strlen( rv_url ) - 1 ).
    ENDIF.
    IF rv_url CP '*.GIT'.
      rv_url = substring( val = rv_url len = strlen( rv_url ) - 4 ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.

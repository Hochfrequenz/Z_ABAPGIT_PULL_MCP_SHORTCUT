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

    TYPES: BEGIN OF ty_candidate,
             key     TYPE string,
             offline TYPE abap_bool,
           END OF ty_candidate,
           ty_candidates TYPE STANDARD TABLE OF ty_candidate WITH EMPTY KEY,
           ty_indexes    TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    "! The online repository with exactly this abapGit key (12 digits, see
    "! normalise_key), or an unbound reference if there is none. A key is
    "! unique, so there is no ambiguity case.
    CLASS-METHODS find_online_repo_by_key
      IMPORTING
        iv_key         TYPE csequence
      RETURNING
        VALUE(ro_repo) TYPE REF TO zcl_abapgit_repo_online
      RAISING
        zcx_abapgit_exception.

    "! Pure comparison: row numbers of the candidates that are online and whose
    "! key equals iv_key exactly. Needs no abapGit service.
    CLASS-METHODS select_by_key
      IMPORTING
        it_candidates   TYPE ty_candidates
        iv_key          TYPE csequence
      RETURNING
        VALUE(rt_index) TYPE ty_indexes.

    "! Trims, requires digits only and at most 12 characters, then pads with
    "! zeros on the left to 12 (12 gives 000000000012). Returns an empty string
    "! for an empty or an invalid value: never a truncated one.
    CLASS-METHODS normalise_key
      IMPORTING
        iv_key        TYPE csequence
      RETURNING
        VALUE(rv_key) TYPE string.

    "! Validates the PULL selectors P_REPO and P_KEY. Returns the error text, or
    "! an empty string if exactly one is given and a given key is valid.
    CLASS-METHODS check_selector
      IMPORTING
        iv_repo         TYPE csequence
        iv_key          TYPE csequence
      RETURNING
        VALUE(rv_error) TYPE string.

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


  METHOD find_online_repo_by_key.

    DATA lt_candidates TYPE ty_candidates.
    DATA lt_repos      TYPE STANDARD TABLE OF REF TO zcl_abapgit_repo WITH EMPTY KEY.

    " Same online-only semantics as find_online_repos.
    LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( iv_offline = abap_false ) INTO DATA(li_repo).
      APPEND VALUE #( key     = li_repo->ms_data-key
                      offline = li_repo->is_offline( ) ) TO lt_candidates.
      APPEND li_repo TO lt_repos.
    ENDLOOP.

    DATA(lt_index) = select_by_key( it_candidates = lt_candidates
                                    iv_key        = iv_key ).
    IF lines( lt_index ) = 1.
      TRY.
          ro_repo ?= lt_repos[ lt_index[ 1 ] ].
        CATCH cx_sy_move_cast_error.
          CLEAR ro_repo.
      ENDTRY.
    ENDIF.

  ENDMETHOD.


  METHOD select_by_key.

    IF iv_key IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT it_candidates INTO DATA(ls_candidate).
      IF ls_candidate-offline = abap_false AND ls_candidate-key = iv_key.
        APPEND sy-tabix TO rt_index.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD normalise_key.

    DATA(lv_key) = condense( CONV string( iv_key ) ).
    IF lv_key IS INITIAL OR strlen( lv_key ) > 12 OR lv_key CN '0123456789'.
      RETURN.
    ENDIF.
    rv_key = |{ lv_key WIDTH = 12 ALIGN = RIGHT PAD = '0' }|.

  ENDMETHOD.


  METHOD check_selector.

    DATA(lv_key) = condense( CONV string( iv_key ) ).

    IF iv_repo IS NOT INITIAL AND lv_key IS NOT INITIAL.
      rv_error = `Use either P_REPO or P_KEY, not both`.
    ELSEIF iv_repo IS INITIAL AND lv_key IS INITIAL.
      rv_error = `P_REPO or P_KEY is required for PULL action`.
    ELSEIF lv_key IS NOT INITIAL AND normalise_key( lv_key ) IS INITIAL.
      " The value is cut to keep the whole text within one message field
      " (50 characters), so the hint after it stays readable.
      IF strlen( lv_key ) > 14.
        lv_key = |{ substring( val = lv_key len = 11 ) }...|.
      ENDIF.
      rv_error = |Invalid P_KEY: { lv_key } (digits only, max 12)|.
    ENDIF.

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

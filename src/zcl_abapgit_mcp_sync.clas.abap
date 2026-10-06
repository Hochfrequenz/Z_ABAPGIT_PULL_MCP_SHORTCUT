"! <p class="shorttext synchronized">abapGit sync: list, pull and push without SAP GUI</p>
"! Logic behind the ADT endpoints under /sap/bc/adt/abapgitsync/ and the
"! exact repository matching used by the report Z_ABAPGIT_PULL_MCP_SHORTCUT.
"! The contract is the design spec on Hochfrequenz/aibap.mcp#135.
CLASS zcl_abapgit_mcp_sync DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES ty_online_repos TYPE STANDARD TABLE OF REF TO zcl_abapgit_repo_online WITH EMPTY KEY.

    "! @parameter io_git_auth | credential preflight; default uses ZGIT_&lt;SAP user&gt;
    METHODS constructor
      IMPORTING
        io_git_auth TYPE REF TO zcl_abapgit_mcp_git_auth OPTIONAL.

    METHODS list
      RETURNING
        VALUE(rt_repos) TYPE zif_abapgit_mcp_sync=>ty_repos
      RAISING
        zcx_abapgit_mcp_sync.

    METHODS pull
      IMPORTING
        is_request       TYPE zif_abapgit_mcp_sync=>ty_pull_request
      RETURNING
        VALUE(rs_result) TYPE zif_abapgit_mcp_sync=>ty_pull_result
      RAISING
        zcx_abapgit_mcp_sync.

    METHODS push
      IMPORTING
        is_request       TYPE zif_abapgit_mcp_sync=>ty_push_request
      RETURNING
        VALUE(rs_result) TYPE zif_abapgit_mcp_sync=>ty_push_result
      RAISING
        zcx_abapgit_mcp_sync.

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

    "! ISO 8601 in UTC, e.g. 2026-10-06T07:42:34Z; empty for an initial value
    CLASS-METHODS to_iso_timestamp
      IMPORTING
        iv_timestamp   TYPE timestampl
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.

    TYPES ty_tadir_tt TYPE zif_abapgit_definitions=>ty_tadir_tt.

    DATA mo_git_auth TYPE REF TO zcl_abapgit_mcp_git_auth.

    METHODS resolve_repo
      IMPORTING
        iv_repo        TYPE string
      RETURNING
        VALUE(ro_repo) TYPE REF TO zcl_abapgit_repo_online
      RAISING
        zcx_abapgit_mcp_sync.

    METHODS check_transport
      IMPORTING
        iv_transport TYPE string
      CHANGING
        cs_checks    TYPE zif_abapgit_definitions=>ty_deserialize_checks
      RAISING
        zcx_abapgit_mcp_sync.

    METHODS decision_entries
      IMPORTING
        is_checks         TYPE zif_abapgit_definitions=>ty_deserialize_checks
      RETURNING
        VALUE(rt_entries) TYPE zcl_abapgit_mcp_guard=>ty_decision_entries
      RAISING
        zcx_abapgit_mcp_sync.

    METHODS decide_all
      CHANGING
        cs_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks.

    METHODS delete_confirmed
      IMPORTING
        is_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks
        ii_log    TYPE REF TO zif_abapgit_log
      RAISING
        zcx_abapgit_exception.

    METHODS stage_files
      IMPORTING
        io_repo         TYPE REF TO zcl_abapgit_repo_online
        it_objects      TYPE zif_abapgit_mcp_sync=>ty_objects
      RETURNING
        VALUE(rs_files) TYPE zif_abapgit_definitions=>ty_stage_files
      RAISING
        zcx_abapgit_exception
        zcx_abapgit_mcp_sync.

    METHODS author
      RETURNING
        VALUE(rs_author) TYPE zif_abapgit_mcp_sync=>ty_author.

    CLASS-METHODS action_name
      IMPORTING
        iv_action      TYPE i
      RETURNING
        VALUE(rv_name) TYPE string.

    CLASS-METHODS guard_files
      IMPORTING
        it_status       TYPE zif_abapgit_definitions=>ty_results_tt
      RETURNING
        VALUE(rt_files) TYPE zcl_abapgit_mcp_guard=>ty_files.

    CLASS-METHODS check_states_decidable
      IMPORTING
        it_status TYPE zif_abapgit_definitions=>ty_results_tt
      RAISING
        zcx_abapgit_mcp_sync.

    CLASS-METHODS log_entries
      IMPORTING
        ii_log        TYPE REF TO zif_abapgit_log
      RETURNING
        VALUE(rt_log) TYPE zif_abapgit_mcp_sync=>ty_log.

    CLASS-METHODS log_texts
      IMPORTING
        ii_log          TYPE REF TO zif_abapgit_log
      RETURNING
        VALUE(rt_texts) TYPE string_table.

    CLASS-METHODS raise_internal
      IMPORTING
        ix_error TYPE REF TO cx_root
        ii_log   TYPE REF TO zif_abapgit_log OPTIONAL
      RAISING
        zcx_abapgit_mcp_sync.

ENDCLASS.



CLASS ZCL_ABAPGIT_MCP_SYNC IMPLEMENTATION.


  METHOD action_name.

    rv_name = SWITCH #( iv_action
      WHEN zif_abapgit_objects=>c_deserialize_action-add        THEN zif_abapgit_mcp_sync=>c_action-add
      WHEN zif_abapgit_objects=>c_deserialize_action-update     THEN zif_abapgit_mcp_sync=>c_action-update
      WHEN zif_abapgit_objects=>c_deserialize_action-overwrite  THEN zif_abapgit_mcp_sync=>c_action-overwrite
      WHEN zif_abapgit_objects=>c_deserialize_action-delete     THEN zif_abapgit_mcp_sync=>c_action-delete
      WHEN zif_abapgit_objects=>c_deserialize_action-delete_add THEN zif_abapgit_mcp_sync=>c_action-delete_add
      WHEN zif_abapgit_objects=>c_deserialize_action-packmove   THEN zif_abapgit_mcp_sync=>c_action-packmove
      WHEN zif_abapgit_objects=>c_deserialize_action-no_support THEN zif_abapgit_mcp_sync=>c_action-no_support
      ELSE |{ iv_action }| ).

  ENDMETHOD.


  METHOD author.

    DATA(lo_user) = zcl_abapgit_user_record=>get_instance( sy-uname ).
    rs_author-name  = lo_user->get_name( ).
    rs_author-email = lo_user->get_email( ).
    IF rs_author-name IS INITIAL.
      rs_author-name = sy-uname.
    ENDIF.
    IF rs_author-email IS INITIAL.
      " abapGit's convention for pushes without a maintained e-mail address
      rs_author-email = |{ sy-uname }@localhost|.
    ENDIF.

  ENDMETHOD.


  METHOD check_states_decidable.

    DATA lt_details TYPE string_table.

    LOOP AT it_status INTO DATA(ls_result)
         WHERE obj_type IS NOT INITIAL AND packmove = abap_false.
      IF zcl_abapgit_mcp_guard=>is_decidable_state( iv_lstate = ls_result-lstate
                                                    iv_rstate = ls_result-rstate ) = abap_false
         AND zcl_abapgit_objects=>is_supported( VALUE #( obj_type = ls_result-obj_type
                                                         obj_name = ls_result-obj_name ) ) = abap_true.
        APPEND |{ ls_result-path }{ ls_result-filename } { zcl_abapgit_mcp_guard=>state_text(
                 VALUE #( lstate = ls_result-lstate rstate = ls_result-rstate ) ) }| TO lt_details.
      ENDIF.
    ENDLOOP.

    IF lt_details IS NOT INITIAL.
      zcx_abapgit_mcp_sync=>raise(
        iv_code    = zif_abapgit_mcp_sync=>c_error-internal
        iv_text    = `abapGit cannot classify the state of some files; pull in the abapGit UI`
        it_details = lt_details ).
    ENDIF.

  ENDMETHOD.


  METHOD check_transport.

    DATA lv_transport TYPE trkorr.

    lv_transport = to_upper( iv_transport ).

    IF cs_checks-transport-required = abap_true AND lv_transport IS INITIAL.
      zcx_abapgit_mcp_sync=>raise(
        iv_code = zif_abapgit_mcp_sync=>c_error-transport_required
        iv_text = |The package records changes; pass "transport" (request type { cs_checks-transport-type-request })| ).
    ENDIF.

    IF lv_transport IS INITIAL.
      RETURN.
    ENDIF.

    " Without a modifiable task, deserialize silently writes nothing
    SELECT SINGLE @abap_true FROM e070
      WHERE strkorr  = @lv_transport
        AND as4user  = @sy-uname
        AND trstatus = 'D'
      INTO @DATA(lv_task_exists).
    IF sy-subrc <> 0 OR lv_task_exists = abap_false.
      zcx_abapgit_mcp_sync=>raise(
        iv_code = zif_abapgit_mcp_sync=>c_error-no_modifiable_task
        iv_text = |User { sy-uname } has no modifiable task in { lv_transport }| ).
    ENDIF.

    cs_checks-transport-transport = lv_transport.

  ENDMETHOD.


  METHOD constructor.

    mo_git_auth = COND #( WHEN io_git_auth IS BOUND THEN io_git_auth ELSE NEW #( ) ).

  ENDMETHOD.


  METHOD decide_all.

    FIELD-SYMBOLS <lt_table> TYPE ANY TABLE.

    DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( cs_checks ) ).

    LOOP AT lo_struct->get_components( ) INTO DATA(ls_component)
         WHERE type->kind = cl_abap_typedescr=>kind_table.
      ASSIGN COMPONENT ls_component-name OF STRUCTURE cs_checks TO <lt_table>.
      LOOP AT <lt_table> ASSIGNING FIELD-SYMBOL(<ls_row>).
        ASSIGN COMPONENT 'DECISION' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_decision>).
        IF sy-subrc <> 0.
          EXIT.
        ENDIF.
        <lv_decision> = zif_abapgit_definitions=>c_yes.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD decision_entries.

    FIELD-SYMBOLS <lt_table> TYPE ANY TABLE.

    " Walks the checks structure by RTTI, so that a decision table added by a
    " newer abapGit is noticed and fails closed instead of being ignored
    DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( is_checks ) ).

    LOOP AT lo_struct->get_components( ) INTO DATA(ls_component).
      ASSIGN COMPONENT ls_component-name OF STRUCTURE is_checks TO FIELD-SYMBOL(<lg_component>).

      CASE ls_component-type->kind.
        WHEN cl_abap_typedescr=>kind_table.
          ASSIGN <lg_component> TO <lt_table>.
          LOOP AT <lt_table> ASSIGNING FIELD-SYMBOL(<ls_row>).
            ASSIGN COMPONENT 'DECISION' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_decision>) ##NEEDED.
            IF sy-subrc <> 0.
              EXIT.
            ENDIF.
            ASSIGN COMPONENT 'OBJ_TYPE' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_obj_type>).
            ASSIGN COMPONENT 'OBJ_NAME' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_obj_name>).
            ASSIGN COMPONENT 'TEXT' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_text>).

            APPEND INITIAL LINE TO rt_entries ASSIGNING FIELD-SYMBOL(<ls_entry>).
            <ls_entry>-table = ls_component-name.
            IF <lv_obj_type> IS ASSIGNED.
              <ls_entry>-obj_type = <lv_obj_type>.
            ENDIF.
            IF <lv_obj_name> IS ASSIGNED.
              <ls_entry>-obj_name = <lv_obj_name>.
            ENDIF.
            IF <lv_text> IS ASSIGNED.
              <ls_entry>-text = <lv_text>.
            ENDIF.

            CASE ls_component-name.
              WHEN zcl_abapgit_mcp_guard=>c_table-overwrite.
                ASSIGN COMPONENT 'ACTION' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_action>).
                <ls_entry>-action = action_name( <lv_action> ).
              WHEN zcl_abapgit_mcp_guard=>c_table-warning_package.
                <ls_entry>-action = zif_abapgit_mcp_sync=>c_action-package.
              WHEN OTHERS.
                <ls_entry>-action = to_lower( ls_component-name ).
            ENDCASE.
            UNASSIGN: <lv_obj_type>, <lv_obj_name>, <lv_text>.
          ENDLOOP.

        WHEN cl_abap_typedescr=>kind_struct.
          CASE ls_component-name.
            WHEN 'REQUIREMENTS' OR 'DEPENDENCIES' OR 'TRANSPORT' OR 'CUSTOMIZING'.
              CONTINUE.
          ENDCASE.
          ASSIGN COMPONENT 'DECISION' OF STRUCTURE <lg_component> TO <lv_decision>.
          IF sy-subrc = 0.
            zcx_abapgit_mcp_sync=>raise(
              iv_code = zif_abapgit_mcp_sync=>c_error-internal
              iv_text = |abapGit asks for a decision on { ls_component-name } that this companion does not know; | &&
                        |pull in the abapGit UI| ).
          ENDIF.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.


  METHOD delete_confirmed.

    DATA lt_tadir TYPE ty_tadir_tt.

    LOOP AT is_checks-overwrite INTO DATA(ls_overwrite)
         WHERE ( action = zif_abapgit_objects=>c_deserialize_action-delete
              OR action = zif_abapgit_objects=>c_deserialize_action-delete_add )
           AND decision = zif_abapgit_definitions=>c_yes.
      APPEND VALUE #( pgmid    = 'R3TR'
                      object   = ls_overwrite-obj_type
                      obj_name = ls_overwrite-obj_name
                      devclass = ls_overwrite-devclass ) TO lt_tadir.
    ENDLOOP.

    IF lt_tadir IS INITIAL.
      RETURN.
    ENDIF.

    zcl_abapgit_objects=>delete( it_tadir  = lt_tadir
                                 is_checks = VALUE #( transport = is_checks-transport )
                                 ii_log    = ii_log ).

  ENDMETHOD.


  METHOD find_online_repos.

    DATA lo_online TYPE REF TO zcl_abapgit_repo_online.

    " Two comparands on purpose: the URL is normalised (a trailing slash and a
    " .git suffix are noise there), the name is only uppercased.
    DATA(lv_want_url)  = normalise_url( iv_repo ).
    DATA(lv_want_name) = to_upper( iv_repo ).

    LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( iv_offline = abap_false ) INTO DATA(li_repo).
      " Defensive: an unguarded cast would abort the search on one bad entry
      TRY.
          lo_online ?= li_repo.
        CATCH cx_sy_move_cast_error.
          CONTINUE.
      ENDTRY.

      IF to_upper( lo_online->get_name( ) ) = lv_want_name
         OR normalise_url( lo_online->get_url( ) ) = lv_want_url.
        APPEND lo_online TO rt_hits.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD guard_files.

    rt_files = VALUE #( FOR ls_result IN it_status
                        ( obj_type = ls_result-obj_type
                          obj_name = ls_result-obj_name
                          path     = ls_result-path
                          filename = ls_result-filename
                          lstate   = ls_result-lstate
                          rstate   = ls_result-rstate ) ).

  ENDMETHOD.


  METHOD list.

    TRY.
        LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( ) INTO DATA(li_repo).
          APPEND VALUE #( key             = li_repo->ms_data-key
                          name            = li_repo->get_name( )
                          package         = li_repo->get_package( )
                          branch          = li_repo->ms_data-branch_name
                          offline         = li_repo->is_offline( )
                          deserialized_at = to_iso_timestamp( li_repo->ms_data-deserialized_at )
                          deserialized_by = li_repo->ms_data-deserialized_by )
            TO rt_repos ASSIGNING FIELD-SYMBOL(<ls_repo>).
          IF li_repo->is_offline( ) = abap_false.
            <ls_repo>-url = CAST zcl_abapgit_repo_online( li_repo )->get_url( ).
          ENDIF.
        ENDLOOP.
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        raise_internal( lx_error ).
    ENDTRY.

  ENDMETHOD.


  METHOD log_entries.

    IF ii_log IS NOT BOUND.
      RETURN.
    ENDIF.

    rt_log = VALUE #( FOR ls_message IN ii_log->get_messages( )
                      ( type     = ls_message-type
                        text     = ls_message-text
                        obj_type = ls_message-obj_type
                        obj_name = ls_message-obj_name ) ).

  ENDMETHOD.


  METHOD log_texts.

    rt_texts = VALUE #( FOR ls_entry IN log_entries( ii_log )
                        ( |{ ls_entry-type } { ls_entry-text }| ) ).

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


  METHOD pull.

    DATA li_log TYPE REF TO zif_abapgit_log.

    IF is_request-repo IS INITIAL.
      zcx_abapgit_mcp_sync=>raise( iv_code = zif_abapgit_mcp_sync=>c_error-bad_request
                                   iv_text = `Member "repo" is required` ).
    ENDIF.

    DATA(lo_repo) = resolve_repo( is_request-repo ).
    rs_result-repo = VALUE #( name    = lo_repo->get_name( )
                              url     = lo_repo->get_url( )
                              package = lo_repo->get_package( ) ).

    mo_git_auth->preflight( iv_url                  = rs_result-repo-url
                            iv_service              = zcl_abapgit_mcp_git_auth=>c_service-upload_pack
                            iv_credentials_required = abap_false ).

    TRY.
        " Computed first: deserialize_checks( ) dumps on file states it cannot classify
        DATA(lt_status) = zcl_abapgit_repo_status=>calculate( lo_repo ).
        check_states_decidable( lt_status ).

        DATA(ls_checks) = lo_repo->zif_abapgit_repo~deserialize_checks( ).
        check_transport( EXPORTING iv_transport = is_request-transport
                         CHANGING  cs_checks    = ls_checks ).
        IF ls_checks-requirements-met = zif_abapgit_definitions=>c_no
           OR ls_checks-dependencies-met = zif_abapgit_definitions=>c_no.
          zcx_abapgit_mcp_sync=>raise(
            iv_code = zif_abapgit_mcp_sync=>c_error-requirements_not_met
            iv_text = `abapGit reports unmet software requirements or APACK dependencies; resolve them in the abapGit UI` ).
        ENDIF.

        rs_result-confirmations_required = zcl_abapgit_mcp_guard=>unconfirmed_pull_entries(
          it_entries = decision_entries( ls_checks )
          it_files   = guard_files( lt_status )
          it_confirm = is_request-confirm ).
        IF rs_result-confirmations_required IS NOT INITIAL.
          rs_result-status = zif_abapgit_mcp_sync=>c_status-needs_confirmation.
          RETURN.
        ENDIF.

        " Same order as the abapGit UI (zcl_abapgit_services_repo=>real_deserialize):
        " deserialize( ) itself never deletes objects
        decide_all( CHANGING cs_checks = ls_checks ).
        li_log = NEW zcl_abapgit_log( ).
        delete_confirmed( is_checks = ls_checks
                          ii_log    = li_log ).
        lo_repo->zif_abapgit_repo~refresh( iv_drop_log = abap_false ).
        lo_repo->zif_abapgit_repo~deserialize( is_checks = ls_checks
                                               ii_log    = li_log ).

        rs_result-status = zif_abapgit_mcp_sync=>c_status-pulled.
        rs_result-log    = log_entries( li_log ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        raise_internal( ix_error = lx_error
                        ii_log   = li_log ).
    ENDTRY.

  ENDMETHOD.


  METHOD push.

    DATA lt_missing TYPE string_table.

    IF is_request-repo IS INITIAL OR is_request-objects IS INITIAL OR is_request-message IS INITIAL.
      zcx_abapgit_mcp_sync=>raise( iv_code = zif_abapgit_mcp_sync=>c_error-bad_request
                                   iv_text = `Members "repo", "objects" and "message" are required` ).
    ENDIF.

    DATA(lo_repo) = resolve_repo( is_request-repo ).
    mo_git_auth->preflight( iv_url                  = lo_repo->get_url( )
                            iv_service              = zcl_abapgit_mcp_git_auth=>c_service-receive_pack
                            iv_credentials_required = abap_true ).

    TRY.
        DATA(lt_files) = guard_files( zcl_abapgit_repo_status=>calculate( lo_repo ) ).

        LOOP AT is_request-objects INTO DATA(ls_object).
          DATA(lv_type) = to_upper( ls_object-obj_type ).
          DATA(lv_name) = to_upper( ls_object-obj_name ).
          IF NOT line_exists( lt_files[ obj_type = lv_type obj_name = lv_name ] ).
            APPEND |{ lv_type } { lv_name }| TO lt_missing.
          ENDIF.
        ENDLOOP.
        IF lt_missing IS NOT INITIAL.
          zcx_abapgit_mcp_sync=>raise( iv_code    = zif_abapgit_mcp_sync=>c_error-object_not_in_repo
                                       iv_text    = |Objects do not belong to repository { lo_repo->get_name( ) }|
                                       it_details = lt_missing ).
        ENDIF.

        " abapGit's stage logic compares SHA1 only and cannot tell which side
        " changed a file: staging a Git-only change would revert it
        DATA(lt_remote_changed) = zcl_abapgit_mcp_guard=>remote_changed_files( it_objects = is_request-objects
                                                                              it_files   = lt_files ).
        IF lt_remote_changed IS NOT INITIAL.
          zcx_abapgit_mcp_sync=>raise(
            iv_code    = zif_abapgit_mcp_sync=>c_error-remote_changed
            iv_text    = `Files of the selected objects changed in Git since the last pull; pull first`
            it_details = lt_remote_changed ).
        ENDIF.

        " The remote is not refreshed from here on: abapGit's cached fetch keeps
        " the stage list and the parent commit of the push consistent
        DATA(ls_stage_files) = stage_files( io_repo    = lo_repo
                                            it_objects = is_request-objects ).
        DATA(lo_stage) = NEW zcl_abapgit_stage( ).
        LOOP AT ls_stage_files-local INTO DATA(ls_local).
          READ TABLE ls_stage_files-status INTO DATA(ls_status)
            WITH TABLE KEY path = ls_local-file-path filename = ls_local-file-filename.
          IF sy-subrc <> 0.
            CLEAR ls_status.
          ENDIF.
          lo_stage->add( iv_path     = ls_local-file-path
                         iv_filename = ls_local-file-filename
                         iv_data     = ls_local-file-data
                         is_status   = ls_status ).
          APPEND VALUE #( path     = ls_local-file-path
                          filename = ls_local-file-filename
                          action   = zif_abapgit_mcp_sync=>c_action-add ) TO rs_result-files.
        ENDLOOP.
        LOOP AT ls_stage_files-remote INTO DATA(ls_remote).
          READ TABLE ls_stage_files-status INTO ls_status
            WITH TABLE KEY path = ls_remote-path filename = ls_remote-filename.
          IF sy-subrc <> 0.
            CLEAR ls_status.
          ENDIF.
          lo_stage->rm( iv_path     = ls_remote-path
                        iv_filename = ls_remote-filename
                        is_status   = ls_status ).
          APPEND VALUE #( path     = ls_remote-path
                          filename = ls_remote-filename
                          action   = zif_abapgit_mcp_sync=>c_action-rm ) TO rs_result-files.
        ENDLOOP.

        rs_result-author = author( ).
        IF lo_stage->count( ) = 0.
          rs_result-status = zif_abapgit_mcp_sync=>c_status-nothing_to_push.
          RETURN.
        ENDIF.
        IF is_request-dry_run = abap_true.
          rs_result-status = zif_abapgit_mcp_sync=>c_status-dry_run.
          RETURN.
        ENDIF.
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        raise_internal( lx_error ).
    ENDTRY.

    TRY.
        lo_repo->push( is_comment = VALUE #( committer = VALUE #( name  = rs_result-author-name
                                                                  email = rs_result-author-email )
                                             author    = VALUE #( name  = rs_result-author-name
                                                                  email = rs_result-author-email )
                                             comment   = is_request-message )
                       io_stage   = lo_stage ).
        rs_result-commit = to_lower( lo_repo->get_current_remote( ) ).
        rs_result-status = zif_abapgit_mcp_sync=>c_status-pushed.
      CATCH zcx_abapgit_exception INTO lx_error.
        zcx_abapgit_mcp_sync=>raise( iv_code     = zif_abapgit_mcp_sync=>c_error-git_error
                                     iv_text     = lx_error->get_text( )
                                     ix_previous = lx_error ).
    ENDTRY.

  ENDMETHOD.


  METHOD raise_internal.

    zcx_abapgit_mcp_sync=>raise( iv_code     = zif_abapgit_mcp_sync=>c_error-internal
                                 iv_text     = ix_error->get_text( )
                                 it_details  = log_texts( ii_log )
                                 ix_previous = ix_error ).

  ENDMETHOD.


  METHOD resolve_repo.

    TRY.
        DATA(lt_hits) = find_online_repos( iv_repo ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        raise_internal( lx_error ).
    ENDTRY.

    CASE lines( lt_hits ).
      WHEN 0.
        zcx_abapgit_mcp_sync=>raise( iv_code = zif_abapgit_mcp_sync=>c_error-repo_not_found
                                     iv_text = |No online repository matches { iv_repo } (exact name or URL)| ).
      WHEN 1.
        ro_repo = lt_hits[ 1 ].
      WHEN OTHERS.
        zcx_abapgit_mcp_sync=>raise(
          iv_code    = zif_abapgit_mcp_sync=>c_error-repo_ambiguous
          iv_text    = |{ iv_repo } matches { lines( lt_hits ) } repositories|
          it_details = VALUE #( FOR lo_hit IN lt_hits ( |{ lo_hit->get_name( ) } { lo_hit->get_package( ) }| ) ) ).
    ENDCASE.

  ENDMETHOD.


  METHOD stage_files.

    DATA lo_logic TYPE REF TO object.
    DATA lt_params TYPE abap_parmbind_tab.

    " The stage logic moved in the refactor released with abapGit 1.132.0, and
    " the repository parameter was renamed from IO_REPO to II_REPO. Both are
    " resolved at runtime, so that the companion compiles on both versions.
    DATA(lo_factory) = CAST cl_abap_classdescr( cl_abap_typedescr=>describe_by_name( 'ZCL_ABAPGIT_STAGE_LOGIC' ) ).
    IF line_exists( lo_factory->methods[ name = 'GET_STAGE_LOGIC' ] ).
      DATA(lv_factory_class) = `ZCL_ABAPGIT_STAGE_LOGIC`.
    ELSE.
      lo_factory = CAST cl_abap_classdescr( cl_abap_typedescr=>describe_by_name( 'ZCL_ABAPGIT_FACTORY' ) ).
      lv_factory_class = `ZCL_ABAPGIT_FACTORY`.
    ENDIF.
    DATA(ls_factory_method) = lo_factory->methods[ name = 'GET_STAGE_LOGIC' ].
    DATA(lv_returning) = ls_factory_method-parameters[ parm_kind = cl_abap_objectdescr=>returning ]-name.
    lt_params = VALUE #( ( name = lv_returning kind = cl_abap_objectdescr=>receiving value = REF #( lo_logic ) ) ).
    CALL METHOD (lv_factory_class)=>('GET_STAGE_LOGIC') PARAMETER-TABLE lt_params.

    DATA(lo_intf) = CAST cl_abap_intfdescr( cl_abap_typedescr=>describe_by_name( 'ZIF_ABAPGIT_STAGE_LOGIC' ) ).
    DATA(ls_get) = lo_intf->methods[ name = 'GET' ].

    DATA(li_filter) = CAST zif_abapgit_object_filter( NEW lcl_object_filter( it_objects ) ).
    CLEAR lt_params.
    LOOP AT ls_get-parameters INTO DATA(ls_param).
      CASE ls_param-name.
        WHEN 'IO_REPO' OR 'II_REPO'.
          INSERT VALUE #( name = ls_param-name kind = cl_abap_objectdescr=>exporting value = REF #( io_repo ) )
            INTO TABLE lt_params.
        WHEN 'II_OBJ_FILTER'.
          INSERT VALUE #( name = ls_param-name kind = cl_abap_objectdescr=>exporting value = REF #( li_filter ) )
            INTO TABLE lt_params.
        WHEN OTHERS.
          IF ls_param-parm_kind = cl_abap_objectdescr=>returning.
            INSERT VALUE #( name = ls_param-name kind = cl_abap_objectdescr=>receiving value = REF #( rs_files ) )
              INTO TABLE lt_params.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    TRY.
        CALL METHOD lo_logic->('ZIF_ABAPGIT_STAGE_LOGIC~GET') PARAMETER-TABLE lt_params.
      CATCH cx_sy_dyn_call_error INTO DATA(lx_call).
        raise_internal( lx_call ).
    ENDTRY.

  ENDMETHOD.


  METHOD to_iso_timestamp.

    IF iv_timestamp IS INITIAL.
      RETURN.
    ENDIF.

    CONVERT TIME STAMP iv_timestamp TIME ZONE 'UTC' INTO DATE DATA(lv_date) TIME DATA(lv_time).
    rv_text = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }T{ lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }Z|.

  ENDMETHOD.
ENDCLASS.

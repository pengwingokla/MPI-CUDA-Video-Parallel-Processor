#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# --- Configuration (USER MUST EDIT THIS SECTION) ---
# ==============================================================================
HOSTS_INFO=(
    "myko@192.168.1.158 50"  # Master: 'nixos' (Quadro M1200, sm_50)
    "myko@192.168.1.97 50"   # Worker: 'laptopB' (Quadro M1200, sm_50)
)
USE_SHARED_FILESYSTEM=false
VERBOSE_RSYNC=false
MPI_NETWORK_INTERFACE="" 
INPUT_VIDEO_FILE="cappy.mp4" # Ensure this is in ROOT_DIR

# --- Project & Script Globals ---
DEFAULT_USER=$(whoami)
MASTER_HOSTNAME_SHORT=$(hostname -s)
# This script should be in <friends_project_root>/bash_scripts/
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" 
LOGS_BASE_DIR="$ROOT_DIR/logs"
mkdir -p "$LOGS_BASE_DIR"

SESSION_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_ID="friends_multirun_${SESSION_TIMESTAMP}_${MASTER_HOSTNAME_SHORT}"
SESSION_LOG_DIR="$LOGS_BASE_DIR/$SESSION_ID"
mkdir -p "$SESSION_LOG_DIR"
ORCHESTRATION_LOG="$SESSION_LOG_DIR/main_orchestration.log"
MPI_HOSTFILE_PATH="$SESSION_LOG_DIR/mpi_cluster_hosts.txt"

CSV_OUTPUT_FILE="$LOGS_BASE_DIR/summary_friends_multi_${SESSION_TIMESTAMP}.csv"
GIT_COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "N/A") 

_PARSED_USER=""; _PARSED_HOST=""; _PARSED_ARCH_CODE=""
COMBINED_CUDA_ARCH_FLAGS_FOR_MAKE=""

EXEC_DIR_REL="exec" # Relative to ROOT_DIR where executables are placed by Makefile
EXEC_SERIAL="exec_serial"; EXEC_MPI_ONLY="exec_mpi_only"; EXEC_CUDA_ONLY="exec_cuda_only"; EXEC_FULL="exec_full"
OUTPUT_DIR_REL="output" # Relative to ROOT_DIR
OUTPUT_SERIAL_FRAMES_DIR_REL="$OUTPUT_DIR_REL/output_serial"
OUTPUT_MPI_FRAMES_DIR_REL="$OUTPUT_DIR_REL/output_mpi"
OUTPUT_CUDA_FRAMES_DIR_REL="$OUTPUT_DIR_REL/output_cuda"
OUTPUT_FULL_FRAMES_DIR_REL="$OUTPUT_DIR_REL/output_mpi_cuda"

BUILD_SUCCEEDED_GLOBAL=false
BUILD_MESSAGE_GLOBAL=""
# This will store the relative path to the make log for the *specific target* that was built.
# e.g., "session_id/make_serial.log", "session_id/make_full.log"
MAKE_LOG_REL_PATH_FOR_TARGET_GLOBAL=""


# ==============================================================================
# --- Helper Functions ---
# ==============================================================================
log_message() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$ORCHESTRATION_LOG"; }
parse_host_info_entry() {
    local full_entry="$1"; _PARSED_ARCH_CODE="${full_entry##* }"; local user_or_host_part="${full_entry% *}"
    if [[ "$user_or_host_part" == *"@"* ]]; then _PARSED_USER="${user_or_host_part%%@*}"; _PARSED_HOST="${user_or_host_part##*@}";
    else _PARSED_USER="$DEFAULT_USER"; _PARSED_HOST="$user_or_host_part"; fi
    if [[ -z "$_PARSED_HOST" || -z "$_PARSED_ARCH_CODE" ]]; then log_message "ERR: Malformed HOSTS_INFO: '$full_entry'."; exit 1; fi
}
write_csv_header() { echo "SessionID,MachineSetOrMaster,GitCommit,EntryTimestamp,ProjectVariant,NumProcesses,MakeLogFile,BuildSucceeded,BuildMessage,RunLogFile,RunCommandSucceeded,RunEnvironmentWarning,RunMessage,OutputVideoCreated,OutputVideoPath,OverallStatusSymbol,OverallStatusMessage,ExecutionTime_ms" > "$CSV_OUTPUT_FILE"; }
log_to_csv_friends() {
    local entry_ts; entry_ts=$(date --iso-8601=seconds)
    local machine_set_id="$MASTER_HOSTNAME_SHORT"
    if [[ "$2" -gt 1 && "${#HOSTS_INFO[@]}" -gt 1 && ("$1" == *"MPI"* || "$1" == *"Full"*) ]]; then
        machine_set_id="CLUSTER_$(echo "${HOSTS_INFO[@]}" | tr ' .@' '_')"
    fi
    # Args: 1:Variant, 2:NP, 3:MakeLogRel, 4:BuildOK, 5:BuildMsg, 6:RunLogRel, 7:RunOK, 8:RunEnvWarn, 9:RunMsg, 10:VideoOK, 11:VideoPath, 12:Symbol, 13:StatusMsg, 14:TimeMs
    printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",%s,\"%s\",%s,\"%s\",\"%s\",%s,%s,\"%s\",%s,\"%s\",\"%s\",\"%s\",%s\n" \
        "$SESSION_ID" "$machine_set_id" "$GIT_COMMIT_HASH" "$entry_ts" \
        "${1//\"/\"\"}" "${2}" "${3//\"/\"\"}" "${4}" "${5//\"/\"\"}" "${6//\"/\"\"}" "${7}" "${8}" "${9//\"/\"\"}" \
        "${10}" "${11//\"/\"\"}" "${12//\"/\"\"}" "${13//\"/\"\"}" "${14}" \
        >> "$CSV_OUTPUT_FILE"
}
run_and_log_command() {
  local cmd_to_run="$1"; shift; local log_file_path="$1"; shift
  log_message "  -> Executing: $cmd_to_run (Log: $(basename "$SESSION_LOG_DIR")/$(basename "$log_file_path"))"
  mkdir -p "$(dirname "$log_file_path")"; touch "$log_file_path" && > "$log_file_path"
  if eval "$cmd_to_run" >>"$log_file_path" 2>&1; then log_message "    [✔ Command Succeeded]"; return 0;
  else
    local exit_code=$?;
    if grep -q -E "Could not find device file|No CUDA-capable device detected|PMIx coord service not available|Unavailable consoles" "$log_file_path"; then log_message "    [⚠ Warning (exit $exit_code) - System/CUDA Env Issue - see log]"; return 2;
    elif grep -q -E "There are not enough slots available|orted context|named symbol not found|no kernel image is available|cannot open shared object file|Library not found" "$log_file_path"; then log_message "    [⚠ Warning (exit $exit_code) - MPI/CUDA Arch/Lib Issue - see log]"; return 2;
    else log_message "    [✘ Failed (exit $exit_code) – see log]"; return 1; fi
  fi
}
_print_table_border_char() { local l="$1" m="$2" r="$3"; local c_arr=(25 5 12 45 22); printf "%s" "$l"; for i in "${!c_arr[@]}"; do local w=${c_arr[i]}; local seg=$((w + 2)); for ((j=0;j<seg;j++));do printf '═';done; if((i<${#c_arr[@]}-1));then printf "%s" "$m";else printf "%s\n" "$r";fi;done;}
_center_text_in_cell() { local width=$1; local text=$2; if ((${#text}>width));then text="${text:0:$((width-3))}...";fi; local tl=${#text};local pt=$((width-tl));local ps=$((pt/2));local pe=$((pt-ps));printf "%*s%s%*s" $ps "" "$text" $pe "";}
print_summary_table_friends() {
    log_message "=== Summary Table (Friend's Project - Master: $MASTER_HOSTNAME_SHORT, Session: $SESSION_ID) ==="
    local cols=(25 5 12 45 22); local headers=(Variant Procs Time "Output Video" Status)
    _print_table_border_char "╔" "╤" "╗"; printf "║"; for i in "${!headers[@]}"; do printf " %s " "$(_center_text_in_cell "${cols[i]}" "${headers[i]}")"; printf "║"; done; echo; _print_table_border_char "╟" "┼" "╢"
    for row_data in "${SUMMARY_FOR_TABLE_FRIENDS[@]}"; do IFS=$'\t' read -r vr pr tm vd st <<<"$row_data"; local v_tr="${vd:0:${cols[3]}}"; local s_tr="${st:0:${cols[4]}}"; printf "║ %-*s ║ %*s ║ %*s ║ %-*s ║ %-*s ║\n" "${cols[0]}" "$vr" "${cols[1]}" "$pr" "${cols[2]}" "$tm" "${cols[3]}" "$v_tr" "${cols[4]}" "$s_tr"; done; _print_table_border_char "╚" "╧" "╝"; echo ""
    log_message "Detailed logs in: $SESSION_LOG_DIR"; log_message "CSV summary: $CSV_OUTPUT_FILE"
}

# ==============================================================================
# --- Initial Global Setup ---
# ==============================================================================
initial_cluster_wide_setup() {
    log_message "--- Running Initial Cluster-Wide Setup for Friend's Project ---"
    # Phase 1: SSH
    log_message "--- Phase 1: SSH Setup ---"
    if [[ ! -f "$HOME/.ssh/id_rsa.pub" ]]; then log_message "No local SSH key. Generating..."; ssh-keygen -t rsa -N "" -f "$HOME/.ssh/id_rsa"; fi
    parse_host_info_entry "${HOSTS_INFO[0]}"; local master_ssh_alias_setup="$_PARSED_USER@$_PARSED_HOST"
    for i_setup in "${!HOSTS_INFO[@]}"; do
        parse_host_info_entry "${HOSTS_INFO[$i_setup]}"; local target_alias_setup="$_PARSED_USER@$_PARSED_HOST"
        log_message "Checking SSH to $target_alias_setup from $master_ssh_alias_setup..."
        if ssh -o PasswordAuthentication=no -o BatchMode=yes -o ConnectTimeout=5 "$target_alias_setup" "exit" &>/dev/null; then log_message "SUCCESS: Passwordless SSH to $target_alias_setup.";
        else
            log_message "INFO: Attempting ssh-copy-id to $target_alias_setup."
            if ssh-copy-id "$target_alias_setup" >> "$ORCHESTRATION_LOG" 2>&1; then
                log_message "INFO: ssh-copy-id $target_alias_setup finished. Verifying..."
                if ssh -o PasswordAuthentication=no -o BatchMode=yes -o ConnectTimeout=5 "$target_alias_setup" "exit" &>/dev/null; then log_message "SUCCESS: Passwordless SSH to $target_alias_setup confirmed.";
                else log_message "ERROR: SSH to $target_alias_setup still fails. Debug manually."; exit 1; fi
            else log_message "ERROR: ssh-copy-id $target_alias_setup command failed. Debug manually."; exit 1; fi
        fi
    done; log_message "--- SSH Setup Phase Completed ---"

    # Prep: CUDA Arch Flags
    declare -A unique_arch_codes_setup; COMBINED_CUDA_ARCH_FLAGS_FOR_MAKE=""
    if [[ "${#HOSTS_INFO[@]}" -gt 0 ]]; then 
        for host_entry_arch_setup in "${HOSTS_INFO[@]}"; do parse_host_info_entry "$host_entry_arch_setup"; unique_arch_codes_setup["$_PARSED_ARCH_CODE"]=1; done
        if [[ "${#unique_arch_codes_setup[@]}" -gt 0 ]]; then
            for code_arch_setup in "${!unique_arch_codes_setup[@]}"; do COMBINED_CUDA_ARCH_FLAGS_FOR_MAKE+="-gencode arch=compute_${code_arch_setup},code=sm_${code_arch_setup} -gencode arch=compute_${code_arch_setup},code=compute_${code_arch_setup} "; done
        fi
    fi
    log_message "Combined CUDA arch flags for builds: $COMBINED_CUDA_ARCH_FLAGS_FOR_MAKE"
    
    # Prep: Input Frames
    log_message "--- Preparing Input Frames (on master node) ---"
    if [[ -f "$ROOT_DIR/$INPUT_VIDEO_FILE" ]]; then
        log_message "Found video $INPUT_VIDEO_FILE. Extracting frames using $ROOT_DIR/src/extract_frames.py..."
        local frame_extraction_log="$SESSION_LOG_DIR/frame_extraction.log"
        # Using python3 directly, assuming nix-shell provides necessary packages (cv2)
        if python3 "$ROOT_DIR/src/extract_frames.py" > "$frame_extraction_log" 2>&1; then
            log_message "Frame extraction complete. See $frame_extraction_log."
            if [ ! -d "$ROOT_DIR/frames" ] || [ -z "$(ls -A "$ROOT_DIR/frames" 2>/dev/null)" ]; then
                log_message "ERROR: Frame extraction reported success, but $ROOT_DIR/frames/ is missing or empty. Check $frame_extraction_log."
                cat "$frame_extraction_log" | tee -a "$ORCHESTRATION_LOG" # Show error in main log too
                exit 1
            fi
        else
            log_message "ERROR: Frame extraction script failed. Ensure 'python3' in current environment has 'cv2' (OpenCV) and '$INPUT_VIDEO_FILE' exists. Check $frame_extraction_log."
            cat "$frame_extraction_log" | tee -a "$ORCHESTRATION_LOG"
            exit 1
        fi
    else
        log_message "WARNING: Input video $INPUT_VIDEO_FILE not found in $ROOT_DIR. Assuming frames are already in $ROOT_DIR/frames/."
        if [ ! -d "$ROOT_DIR/frames" ] || [ -z "$(ls -A "$ROOT_DIR/frames" 2>/dev/null)" ]; then
             log_message "ERROR: $ROOT_DIR/frames/ directory is missing or empty, and no input video to extract from."
             exit 1
        fi
    fi

    # Sync: Project Root (includes frames)
    if [[ "$USE_SHARED_FILESYSTEM" == "true" ]]; then log_message "Shared FS. Skipping rsync.";
    else
        log_message "--- Syncing Project Root to Worker Nodes (includes frames, excludes build/exec/output initially) ---"
        if [[ "${#HOSTS_INFO[@]}" -gt 1 ]]; then
            for i_sync_init in $(seq 1 $((${#HOSTS_INFO[@]} - 1)) ); do
                parse_host_info_entry "${HOSTS_INFO[$i_sync_init]}"; local target_alias_sync_init="$_PARSED_USER@$_PARSED_HOST"
                log_message "Initial sync of $ROOT_DIR/ to $target_alias_sync_init:$ROOT_DIR/"
                if ! ssh "$target_alias_sync_init" "mkdir -p \"$ROOT_DIR\""; then log_message "ERR: mkdir $ROOT_DIR on $target_alias_sync_init failed."; exit 1; fi
                local rsync_opts_init="-az --delete --checksum --exclude '.git/' --exclude 'build/' --exclude '*.mp4' --exclude '*.o' --exclude '$EXEC_DIR_REL/' --exclude '$OUTPUT_DIR_REL/'"
                if [[ "$VERBOSE_RSYNC" == "true" ]]; then rsync_opts_init="-avz --delete --checksum --exclude '.git/' --exclude 'build/' --exclude '*.mp4' --exclude '*.o' --exclude '$EXEC_DIR_REL/' --exclude '$OUTPUT_DIR_REL/'"; fi
                local rsync_log_init="$SESSION_LOG_DIR/rsync_initial_to_${_PARSED_HOST}.log"
                log_message "  Executing rsync (Log: $(basename "$SESSION_LOG_DIR")/$(basename "$rsync_log_init"))..."
                # Ensure log dir exists for rsync log
                mkdir -p "$(dirname "$rsync_log_init")"
                if eval "rsync $rsync_opts_init '$ROOT_DIR/' '$target_alias_sync_init:$ROOT_DIR/'" >"$rsync_log_init" 2>&1; then log_message "SUCCESS: Initial sync to $target_alias_sync_init.";
                else log_message "ERR: Initial rsync to $target_alias_sync_init failed. Check $rsync_log_init."; exit 1; fi
            done
        else log_message "Single host defined; no initial remote sync needed."; fi
    fi; log_message "--- Initial Sync Phase Completed ---"

    # MPI Hostfile
    if [[ "${#HOSTS_INFO[@]}" -gt 0 ]]; then
        log_message "--- Creating MPI Hostfile ---"; rm -f "$MPI_HOSTFILE_PATH"
        for h_entry_mpi_hf in "${HOSTS_INFO[@]}"; do parse_host_info_entry "$h_entry_mpi_hf"; echo "$_PARSED_HOST slots=1" >> "$MPI_HOSTFILE_PATH"; done
        log_message "MPI Hostfile: $MPI_HOSTFILE_PATH"; cat "$MPI_HOSTFILE_PATH" | tee -a "$ORCHESTRATION_LOG"
    else log_message "No hosts in HOSTS_INFO, MPI Hostfile not created."; touch "$MPI_HOSTFILE_PATH"; fi
    log_message "--- MPI Hostfile Creation Phase Completed ---"
    log_message "--- Initial Cluster-Wide Setup Completed ---"
}

# ==============================================================================
# --- Build, Patch (NixOS), and Sync Specific Executables ---
# ==============================================================================
build_patch_and_sync_target() {
    local make_target_name="$1"; local executable_name="$2"; local is_cuda_build="$3"
    log_message "-- Building Target: $make_target_name (Executable: $ROOT_DIR/$EXEC_DIR_REL/$executable_name) --"
    local exec_abs_path="$ROOT_DIR/$EXEC_DIR_REL/$executable_name"

    # Set global path to the make log for this specific target
    MAKE_LOG_REL_PATH_GLOBAL="$SESSION_ID/make_${make_target_name}.log"
    local current_make_log_abs_path="$SESSION_LOG_DIR/make_${make_target_name}.log"
    
    rm -f "$exec_abs_path" 
    log_message "  Attempting to remove old executable: $exec_abs_path"
    
    local make_cmd_build="make -C '$ROOT_DIR' $make_target_name"
    # Friend's Makefile needs to be updated to use HOST_CUDA_ARCH_FLAGS
    # e.g. NVCC_FLAGS += $(HOST_CUDA_ARCH_FLAGS)
    if [[ "$is_cuda_build" == "true" && -n "$COMBINED_CUDA_ARCH_FLAGS_FOR_MAKE" ]]; then
        make_cmd_build="make -C '$ROOT_DIR' HOST_CUDA_ARCH_FLAGS='$COMBINED_CUDA_ARCH_FLAGS_FOR_MAKE' $make_target_name"
        log_message "  (CUDA Build using HOST_CUDA_ARCH_FLAGS: $COMBINED_CUDA_ARCH_FLAGS_FOR_MAKE)"
    fi

    log_message "  Executing build: $make_cmd_build (Log: $MAKE_LOG_REL_PATH_GLOBAL)"
    mkdir -p "$(dirname "$current_make_log_abs_path")" # Ensure log dir exists
    >$current_make_log_abs_path 
    if eval "$make_cmd_build" >> "$current_make_log_abs_path" 2>&1; then
        if [[ -f "$exec_abs_path" ]]; then
            BUILD_SUCCEEDED_GLOBAL=true; BUILD_MESSAGE_GLOBAL="Build OK"
            if command -v patchelf &> /dev/null && [[ "$(uname -s)" == "Linux" ]]; then
                log_message "  Attempting to patchelf $exec_abs_path for NixOS..."
                local LOADER_PATH; LOADER_PATH=$(find /nix/store -maxdepth 2 -type f -path "*/lib/ld-linux-x86-64.so.2" -print -quit 2>/dev/null || echo "")
                local GLIBC_LIB_PATH; GLIBC_LIB_PATH=$(dirname "$LOADER_PATH" 2>/dev/null || echo "")
                local MPI_LIB_PATH; MPI_LIB_PATH=$(dirname "$(find /nix/store -maxdepth 3 -type f -path "*openmpi*/lib/libmpi.so" -print -quit 2>/dev/null || echo "")")
                local CUDART_LIB_PATH; CUDART_LIB_PATH=$(dirname "$(find /nix/store -maxdepth 3 -type f -path "*cudatoolkit*/lib/libcudart.so" -print -quit 2>/dev/null || echo "")")
                
                local RPATH_TO_SET=""
                if [[ -n "$GLIBC_LIB_PATH" ]]; then RPATH_TO_SET+="$GLIBC_LIB_PATH:"; fi
                if [[ -n "$MPI_LIB_PATH" && ("$make_target_name" == "mpi_only" || "$make_target_name" == "full") ]]; then RPATH_TO_SET+="$MPI_LIB_PATH:"; fi
                if [[ -n "$CUDART_LIB_PATH" && "$is_cuda_build" == "true" ]]; then RPATH_TO_SET+="$CUDART_LIB_PATH:"; fi
                RPATH_TO_SET=${RPATH_TO_SET%:}

                if [[ -n "$LOADER_PATH" && -n "$RPATH_TO_SET" ]]; then
                    log_message "    Loader: $LOADER_PATH"; log_message "    RPATH: $RPATH_TO_SET"
                    if patchelf --set-interpreter "$LOADER_PATH" --set-rpath "$RPATH_TO_SET" "$exec_abs_path" >> "$current_make_log_abs_path" 2>&1; then
                        log_message "    [✔ patchelf Succeeded for $executable_name]"
                    else BUILD_MESSAGE_GLOBAL+=" (patchelf failed)"; log_message "    [⚠ patchelf Failed for $executable_name.]"; fi
                else BUILD_MESSAGE_GLOBAL+=" (patchelf skipped)"; log_message "    [⚠ Could not find all paths for patchelf. Skipping for $executable_name.]"; fi
            fi
        else BUILD_SUCCEEDED_GLOBAL=false; BUILD_MESSAGE_GLOBAL="Build OK, but $exec_name_fr MISSING"; fi # Corrected variable
    else local make_exit=$?; BUILD_SUCCEEDED_GLOBAL=false; BUILD_MESSAGE_GLOBAL="Build failed (exit $make_exit)"; fi
    log_message "    Build Status for $executable_name: $BUILD_MESSAGE_GLOBAL"

    if [[ "$BUILD_SUCCEEDED_GLOBAL" == "true" && "$USE_SHARED_FILESYSTEM" == "false" && "${#HOSTS_INFO[@]}" -gt 1 ]]; then
        log_message "  Syncing built $exec_rel_path and critical data to worker nodes..."
        for i_sync_exec_loop in $(seq 1 $((${#HOSTS_INFO[@]} - 1)) ); do
            parse_host_info_entry "${HOSTS_INFO[$i_sync_exec_loop]}"; local target_alias_sync_exec="$_PARSED_USER@$_PARSED_HOST"
            log_message "    Syncing to $target_alias_sync_exec..."
            ssh "$target_alias_sync_exec" "mkdir -p \"$(dirname "$exec_abs_path")\"" 
            local rsync_exec_log="$SESSION_LOG_DIR/rsync_exec_${executable_name}_to_${_PARSED_HOST}.log"
            mkdir -p "$(dirname "$rsync_exec_log")"
            if rsync -az --checksum "$exec_abs_path" "$target_alias_sync_exec:$exec_abs_path" > "$rsync_exec_log" 2>&1; then log_message "      SUCCESS: Synced $executable_name to $target_alias_sync_exec";
            else log_message "      ERROR: Failed to sync $executable_name to $target_alias_sync_exec. Check $rsync_exec_log"; fi
            
            # Sync frames dir (always needed by workers if not shared)
            log_message "    Syncing frames to $target_alias_sync_exec..."
            ssh "$target_alias_sync_exec" "mkdir -p \"$ROOT_DIR/frames\""
            local rsync_frames_log="$SESSION_LOG_DIR/rsync_frames_to_${_PARSED_HOST}.log"
            mkdir -p "$(dirname "$rsync_frames_log")"
            if rsync -az --checksum --delete "$ROOT_DIR/frames/" "$target_alias_sync_exec:$ROOT_DIR/frames/" > "$rsync_frames_log" 2>&1; then log_message "      SUCCESS: Synced frames to $target_alias_sync_exec";
            else log_message "      ERROR: Failed to sync frames to $target_alias_sync_exec. Check $rsync_frames_log"; fi
        done
    fi
}


# ==============================================================================
# --- Test Suite Execution ---
# ==============================================================================
run_friends_test_suite() {
    log_message "--- Starting Friend's Project Test Suite ---"
    write_csv_header

    declare -a tests_to_run_friends
    tests_to_run_friends+=( "Serial;NPS_SINGLE;serial;$EXEC_SERIAL;false;$OUTPUT_SERIAL_FRAMES_DIR_REL;output_serial.mp4" )
    tests_to_run_friends+=( "MPI-Only;NPS_MPI;mpi_only;$EXEC_MPI_ONLY;false;$OUTPUT_MPI_FRAMES_DIR_REL;output_mpi_only.mp4" )
    tests_to_run_friends+=( "CUDA-Only;NPS_SINGLE;cuda_only;$EXEC_CUDA_ONLY;true;$OUTPUT_CUDA_FRAMES_DIR_REL;output_cuda.mp4" )
    tests_to_run_friends+=( "MPI+CUDA Full;NPS_MPI;full;$EXEC_FULL;true;$OUTPUT_FULL_FRAMES_DIR_REL;output_mpi_cuda.mp4" )

    NPS_SINGLE=(1)
    local max_procs_for_mpi_tests=$((${#HOSTS_INFO[@]} > 0 ? ${#HOSTS_INFO[@]} : 4))
    if [[ "$max_procs_for_mpi_tests" -gt 4 ]]; then max_procs_for_mpi_tests=4; fi
    NPS_MPI=(1)
    if [[ "$max_procs_for_mpi_tests" -ge 2 ]]; then NPS_MPI+=(2); fi
    if [[ "$max_procs_for_mpi_tests" -ge 4 && "$max_procs_for_mpi_tests" -ge 4 ]]; then NPS_MPI+=(4); fi # Only add 4 if enough hosts or for local oversubscribe

    declare -A built_targets_map 
    
    for test_params_str_friends in "${tests_to_run_friends[@]}"; do
        IFS=';' read -r variant_name_fr np_array_name_fr make_target_fr exec_name_fr is_cuda_fr output_frames_dir_rel_fr output_video_name_fr <<< "$test_params_str_friends"
        
        if [[ -z "${built_targets_map[$make_target_fr]}" ]]; then
            build_patch_and_sync_target "$make_target_fr" "$exec_name_fr" "$is_cuda_fr"
            built_targets_map["$make_target_fr"]=1 
        else
            log_message "-- Target $make_target_fr (Exec: $exec_name_fr) already built in this session. Using existing build status. --"
        fi
        # Use the global build status variables set by the build function
        local current_build_succeeded_fr=$BUILD_SUCCEEDED_GLOBAL
        local current_build_message_fr=$BUILD_MESSAGE_GLOBAL
        local current_make_log_rel_path_fr=$MAKE_LOG_REL_PATH_GLOBAL 

        eval "current_np_values_fr=(\"\${${np_array_name_fr}[@]}\")"

        for current_np_fr in "${current_np_values_fr[@]}"; do
            if [[ "$current_np_fr" -gt 1 && "${#HOSTS_INFO[@]}" -gt 1 && "$current_np_fr" -gt "${#HOSTS_INFO[@]}" ]]; then
                log_message "  Skipping $variant_name_fr NP=$current_np_fr (exceeds ${#HOSTS_INFO[@]} hosts)."
                continue
            fi

            log_message "=== Testing $variant_name_fr (NP=$current_np_fr) ==="
            
            local current_run_log_name_fr="run_${variant_name_fr// /_}_np${current_np_fr}.log"
            local current_run_log_rel_path_fr="$SESSION_ID/$current_run_log_name_fr"
            local current_run_log_abs_path_fr="$SESSION_LOG_DIR/$current_run_log_name_fr"
            local current_exec_full_path_fr="$ROOT_DIR/$EXEC_DIR_REL/$exec_name_fr" # Absolute path to executable
            local current_output_frames_abs_dir_fr="$ROOT_DIR/$output_frames_dir_rel_fr"

            local run_ok_fr=false; local run_env_warn_fr=false; local run_msg_fr="-"
            local video_ok_fr=false; local video_path_rel_fr="-"; local overall_sym_fr="✘"; local overall_msg_fr="Not Run"; local time_num_val_fr=""

            if [[ "$current_build_succeeded_fr" == "true" ]]; then
                mkdir -p "$current_output_frames_abs_dir_fr" 
                if [[ "$USE_SHARED_FILESYSTEM" == "false" && "${#HOSTS_INFO[@]}" -gt 1 && ("$make_target_fr" == "mpi_only" || "$make_target_fr" == "full") ]]; then
                    log_message "  Ensuring output frame directory $output_frames_dir_rel_fr exists on worker nodes..."
                    for i_mkdir_fr in $(seq 1 $((${#HOSTS_INFO[@]} - 1)) ); do
                        parse_host_info_entry "${HOSTS_INFO[$i_mkdir_fr]}"; local target_alias_mkdir_fr="$_PARSED_USER@$_PARSED_HOST"
                        ssh "$target_alias_mkdir_fr" "mkdir -p '$ROOT_DIR/$output_frames_dir_rel_fr'"
                    done
                fi

                local cmd_to_execute_fr=""; local network_params_fr=""
                if [[ -n "$MPI_NETWORK_INTERFACE" ]]; then network_params_fr="--mca btl_tcp_if_include $MPI_NETWORK_INTERFACE --mca oob_tcp_if_include $MPI_NETWORK_INTERFACE";
                else network_params_fr="--mca btl_tcp_if_exclude lo,docker0,virbr0 --mca oob_tcp_if_exclude lo,docker0,virbr0"; fi

                # Construct command. All runs are from ROOT_DIR for friend's project.
                # The executables are in $EXEC_DIR_REL (e.g. "exec")
                local exec_path_for_cmd="./$EXEC_DIR_REL/$exec_name_fr"

                if [[ "$make_target_fr" == "serial" || "$make_target_fr" == "cuda_only" ]]; then
                    cmd_to_execute_fr="cd '$ROOT_DIR' && $exec_path_for_cmd"
                elif [[ "$current_np_fr" -eq 1 ]]; then
                    cmd_to_execute_fr="cd '$ROOT_DIR' && mpirun -np 1 $exec_path_for_cmd"
                elif [[ "${#HOSTS_INFO[@]}" -gt 1 && -s "$MPI_HOSTFILE_PATH" ]]; then 
                    local mpi_output_log_dir_fr="$ROOT_DIR/$OUTPUT_DIR_REL/$(basename "$output_frames_dir_rel_fr")/logs_np${current_np_fr}"
                    mkdir -p "$mpi_output_log_dir_fr" 
                    # Use absolute path for mpirun when on hostfile to ensure worker nodes find it
                    cmd_to_execute_fr="mpirun -np $current_np_fr --hostfile $MPI_HOSTFILE_PATH --report-bindings $network_params_fr --output-filename '$mpi_output_log_dir_fr/rank' $current_exec_full_path_fr"
                else 
                    cmd_to_execute_fr="cd '$ROOT_DIR' && mpirun --oversubscribe -np $current_np_fr $exec_path_for_cmd"
                fi
                
                local time_start_fr; time_start_fr=$(date +%s.%N)
                local cmd_exec_exit_code_fr=0
                run_and_log_command "$cmd_to_execute_fr" "$current_run_log_abs_path_fr" || cmd_exec_exit_code_fr=$?
                local time_end_fr; time_end_fr=$(date +%s.%N)
                time_num_val_fr=$(echo "$time_end_fr - $time_start_fr" | bc -l | awk '{printf "%.0f", $1*1000}')

                if [[ $cmd_exec_exit_code_fr -eq 0 ]]; then run_ok_fr=true; run_msg_fr="Run OK"; overall_sym_fr="✔"; overall_msg_fr="✔";
                elif [[ $cmd_exec_exit_code_fr -eq 2 ]]; then run_env_warn_fr=true; run_msg_fr="Env Warn"; overall_sym_fr="⚠"; overall_msg_fr="⚠ (env)";
                else run_msg_fr="Runtime Err (exit $cmd_exec_exit_code_fr)"; overall_sym_fr="✘"; overall_msg_fr="✘ (runtime)"; fi

                if $run_ok_fr; then
                    if [[ "$USE_SHARED_FILESYSTEM" == "false" && "$current_np_fr" -gt 1 && "${#HOSTS_INFO[@]}" -gt 1 ]]; then
                        log_message "  Gathering output frames from workers to master for video conversion..."
                        for i_gather_fr in $(seq 1 $((${#HOSTS_INFO[@]} - 1)) ); do # From worker 1 to N-1
                            parse_host_info_entry "${HOSTS_INFO[$i_gather_fr]}"; local worker_alias_gather="$_PARSED_USER@$_PARSED_HOST"
                            local remote_frames_path="$ROOT_DIR/$output_frames_dir_rel_fr/" # Trailing slash for rsync contents
                            local local_frames_path="$ROOT_DIR/$output_frames_dir_rel_fr/"  # Trailing slash
                            log_message "    rsync -avz '$worker_alias_gather:$remote_frames_path' '$local_frames_path'"
                            local rsync_gather_log="$SESSION_LOG_DIR/rsync_gather_frames_from_${_PARSED_HOST}_${make_target_fr}_np${current_np_fr}.log"
                            # This rsync will merge frames; assumes unique filenames per rank or master has rank 0 frames.
                            # If ranks overwrite each other's frames, this won't be correct.
                            # Friend's project probably has ranks write frame_xxxx_rankY.jpg or similar, or to subdirs.
                            # For now, simple merge.
                            if rsync -avz "$worker_alias_gather:$remote_frames_path" "$local_frames_path" > "$rsync_gather_log" 2>&1; then
                               log_message "      SUCCESS: Gathered frames from $worker_alias_gather"
                            else
                               log_message "      WARNING: Failed to gather frames from $worker_alias_gather. Video may be incomplete. Check $rsync_gather_log."
                            fi
                        done
                    fi

                    log_message "  Attempting video conversion for $variant_name_fr NP=$current_np_fr..."
                    local output_video_abs_path_fr="$ROOT_DIR/$output_video_name_fr" # Video saved in project root
                    local ffmpeg_cmd_fr="ffmpeg -y -framerate 30 -i $current_output_frames_abs_dir_fr/frame_%04d.jpg -c:v libx264 -pix_fmt yuv420p -crf 23 '$output_video_abs_path_fr'"
                    if [[ "$make_target_fr" == "serial" ]]; then ffmpeg_cmd_fr="ffmpeg -y -framerate 10 -i $current_output_frames_abs_dir_fr/frame_%04d.jpg -c:v libx264 -pix_fmt yuv420p '$output_video_abs_path_fr'"; fi
                    
                    local ffmpeg_log_path_fr="$SESSION_LOG_DIR/ffmpeg_${variant_name_fr// /_}_np${current_np_fr}.log"
                    log_message "    Executing: $ffmpeg_cmd_fr (Log: $(basename "$SESSION_LOG_DIR")/$(basename "$ffmpeg_log_path_fr"))"
                    if eval "$ffmpeg_cmd_fr" >"$ffmpeg_log_path_fr" 2>&1; then
                        if [[ -s "$output_video_abs_path_fr" ]]; then video_ok_fr=true; video_path_rel_fr="$output_video_name_fr"; log_message "    [✔ Video conversion succeeded]";
                        else video_ok_fr=false; video_path_rel_fr="Conv OK, file empty"; log_message "    [⚠ Video OK, but file empty: $output_video_abs_path_fr]"; overall_sym_fr="⚠"; overall_msg_fr="⚠ (ffmpeg file)"; fi
                    else video_ok_fr=false; video_path_rel_fr="ffmpeg failed"; log_message "    [✘ Video conversion failed. Check $ffmpeg_log_path_fr]"; overall_sym_fr="⚠"; overall_msg_fr="⚠ (ffmpeg err)"; fi
                else video_path_rel_fr="Run failed/skipped"; fi
            else 
                overall_msg_fr="✘ ($current_build_message_fr)"; run_msg_fr="Skip build"; video_path_rel_fr="Skip build"
            fi
            add_to_table_summary_friends "$variant_name_fr" "$current_np_fr" "$time_num_val_fr ms" "$video_path_rel_fr" "$overall_msg_fr"
            log_to_csv_friends "$variant_name_fr" "$current_np_fr" \
                "$current_make_log_rel_path_fr" "$current_build_succeeded_fr" "$current_build_message_fr" \
                "$current_run_log_rel_path_fr" "$run_ok_fr" "$run_env_warn_fr" "$run_msg_fr" \
                "$video_ok_fr" "$video_path_rel_fr" \
                "$overall_sym_fr" "$overall_msg_fr" "$time_num_val_fr"
        done
    done
    log_message "--- Friend's Project Test Suite Finished ---"
}

# ==============================================================================
# --- Main Script Logic ---
# ==============================================================================
main() {
    # Initialize main orchestration log
    echo "Friend's Project: Multi-Machine Full Suite Test Orchestration Log - Session: $SESSION_ID" > "$ORCHESTRATION_LOG"
    log_message "Starting Friend's Project Full Suite Test Script..."
    log_message "Session ID: $SESSION_ID"; log_message "Logging to Directory: $SESSION_LOG_DIR";
    log_message "Project Root (Friend's): $ROOT_DIR";
    
    if [[ "${#HOSTS_INFO[@]}" -eq 0 ]]; then log_message "WARNING: HOSTS_INFO empty. All MPI tests run local on $MASTER_HOSTNAME_SHORT."; fi
    log_message "Target hosts configured:"; for heM_fr in "${HOSTS_INFO[@]}"; do log_message "  - $heM_fr"; done

    initial_cluster_wide_setup 
    run_friends_test_suite        
    print_summary_table_friends   

    log_message "--- Friend's Project Full Suite Test Script Finished ---"
    log_message "All logs: $SESSION_LOG_DIR"; log_message "CSV: $CSV_OUTPUT_FILE"; log_message "Orchestration log: $ORCHESTRATION_LOG"
}

# --- Run Main ---
main
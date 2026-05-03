#!/usr/bin/env bash
set -u

WORKDIR="/home/wcli/mydata/FDTD_sim/eulersbend_opt_20260409"
OUTFILE="$WORKDIR/angle45_live_status.log"
RUN_DATE="${1:-$(date +%Y%m%d)}"
MATLAB_PATTERN="eulersbend_run_six_cases_angle45"

cases=(
  "0.45|1.66|40"
  "0.45|1.66|50"
  "0.45|1.66|55"
  "1.66|0.45|40"
  "1.66|0.45|50"
  "1.66|0.45|55"
)

format_case_dir() {
  local win="$1"
  local wout="$2"
  local rmin="$3"
  printf "/data/wcli/FDTD_sim/eulersbend_opt_20260409data/dat_eulersbend_opt_%s/eulersbend_opt_etch_angle_83_h_wg_0.22_W_in_%s_W_out_%s_R_min_%s_total_angle_deg_45_straight_length_5_N_point_501" \
    "$RUN_DATE" "$win" "$wout" "$rmin"
}

extract_progress_line() {
  local logfile="$1"
  grep -E '% complete|Simulation completed successfully|Early termination of simulation' "$logfile" 2>/dev/null | tail -n 1
}

extract_tlist_summary() {
  local basic_mat="$1"
  matlab -batch "s=load('$basic_mat'); lambda_all_nm=s.T_list{1}.lambda*1e9; lambda_idx=round(length(lambda_all_nm)/2); vals=abs(s.T_list{2}.T_net(lambda_idx,:)); fprintf('lambda_center_nm=%.6f\n', lambda_all_nm(lambda_idx)); fprintf('T_list2_center_col1=%.10f\n', vals(1)); fprintf('T_list2_center_all=['); fprintf(' %.10f', vals); fprintf(' ]\n');" 2>/dev/null | grep -E 'lambda_center_nm=|T_list2_center_col1=|T_list2_center_all='
}

touch "$OUTFILE"

while true; do
  {
    echo "[$(date '+%F %T')] angle45 live status"
    echo
    if pgrep -f "$MATLAB_PATTERN" >/dev/null 2>&1; then
      echo "MATLAB batch: RUNNING"
    else
      echo "MATLAB batch: NOT RUNNING"
    fi
    echo
    local_done=0
    for entry in "${cases[@]}"; do
      IFS='|' read -r win wout rmin <<<"$entry"
      case_dir="$(format_case_dir "$win" "$wout" "$rmin")"
      echo "CASE W_in=$win W_out=$wout R_min=$rmin total_angle=45"
      if [[ -f "$case_dir/basic.mat" ]]; then
        echo "  status: DONE"
        extract_tlist_summary "$case_dir/basic.mat" | sed 's/^/  /'
        local_done=$((local_done + 1))
      elif [[ -f "$case_dir/basic_p0.log" ]]; then
        echo "  status: RUNNING_OR_INCOMPLETE"
        progress_line="$(extract_progress_line "$case_dir/basic_p0.log")"
        if [[ -n "${progress_line:-}" ]]; then
          echo "  latest: $progress_line"
        else
          echo "  latest: log exists but no progress line yet"
        fi
      elif [[ -d "$case_dir" ]]; then
        echo "  status: DIR_CREATED_WAITING_FOR_LOG"
      else
        echo "  status: NOT_STARTED"
      fi
      echo "  dir: $case_dir"
      echo
    done
    echo "Completed cases: $local_done/6"
    echo
    echo "------------------------------------------------------------"
    echo
  } >>"$OUTFILE"

  if ! pgrep -f "$MATLAB_PATTERN" >/dev/null 2>&1; then
    exit 0
  fi
  sleep 20
done

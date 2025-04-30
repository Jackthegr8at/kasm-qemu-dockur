#!/usr/bin/env bash
/usr/bin/desktop_ready
set -e

sleep 2

# --- Function Definitions ---

# Function to perform QEMU startup (checking files, creating overlay, running tini)
start_qemu() {
  echo "[QEMU Startup] Proceeding..."

  if [ -f /kasm_user_share/data.qcow2 ]; then
      echo "[QEMU Startup] /kasm_user_share/data.qcow2 found, creating overlay at /storage/data.qcow2" >> /var/log/qemu_startup.log
      sudo qemu-img create -f qcow2 -b /kasm_user_share/data.qcow2 -F qcow2 /storage/data.qcow2
      sudo cp /kasm_user_share/windows.* /storage
      if [ $? -eq 0 ]; then
          echo "[QEMU Startup] Overlay created, starting tini and entry.sh" >> /var/log/qemu_startup.log
          # Execute tini/entry.sh directly here. It runs in the foreground.
          /usr/bin/tini -s /run/entry.sh
      else
          echo "[QEMU Startup] Failed to create overlay image!" >> /var/log/qemu_startup.log
          return 1 # Indicate failure
      fi
  elif [ -f /storage/data.qcow2 ]; then
      echo "[QEMU Startup] /storage/data.qcow2 found, starting tini and entry.sh" >> /var/log/qemu_startup.log
      # Execute tini/entry.sh directly here. It runs in the foreground.
      /usr/bin/tini -s /run/entry.sh
  else
      echo "[QEMU Startup] No VM image found in /kasm_user_share or /storage, skipping tini/entry.sh" >> /var/log/qemu_startup.log
      return 1 # Indicate no VM started
  fi
  echo "[QEMU Startup] QEMU process (/run/entry.sh) has finished or was skipped."
}

# Function to wait for VM ping and launch RDP in fullscreen
start_rdp_fullscreen() {
    local vm_ip="20.20.20.21"
    local rdp_port="3366"
    local rdp_user="docker"
    local rdp_pass="admin"

    echo "[RDP] Waiting for VM ($vm_ip) to respond to ping..."
    # Loop until ping succeeds
    while ! ping -c 1 -W 1 "$vm_ip" > /dev/null 2>&1; do
        echo "[RDP] VM not ready, waiting 2 seconds..."
        sleep 2
    done

    echo "[RDP] VM is responding! Launching rdesktop in fullscreen..."
    # Launch rdesktop
    echo yes | rdesktop -u "$rdp_user" -p "$rdp_pass" "${vm_ip}:${rdp_port}" -f
    echo "[RDP] rdesktop session finished."
}

# Export functions so they are available to `bash -c` if needed
export -f start_qemu
export -f start_rdp_fullscreen

# --- Main Script Logic ---

# Wait for PulseAudio
echo "Checking PulseAudio status..."
for i in {1..20}; do
  if pactl info >/dev/null 2>&1; then
    echo "PulseAudio is ready."
    sleep 2
    break
  else
    echo "Waiting for PulseAudio to be ready ($i/20)..."
    sleep 1
  fi
done
if ! pactl info >/dev/null 2>&1; then
    echo "PulseAudio did not become ready. Continuing without audio guarantees."
fi


# Check environment variables (provide defaults if not set)
NOAUDIORDP="${NOAUDIORDP:-false}"
RDPFULLSCREEN="${RDPFULLSCREEN:-false}"

echo "NOAUDIORDP=$NOAUDIORDP"
echo "RDPFULLSCREEN=$RDPFULLSCREEN"


# Decide how to run based on NOAUDIORDP
if [[ "$NOAUDIORDP" == "true" ]]; then
  # --- Run QEMU directly (no prompt) ---
  echo "[custom_startup.sh] NOAUDIORDP is true. Starting QEMU directly."

  # Start RDP logic in the background *if* enabled, before starting QEMU
  if [[ "$RDPFULLSCREEN" == "true" ]]; then
      echo "[custom_startup.sh] RDPFULLSCREEN is true. Launching RDP wait loop in background."
      start_rdp_fullscreen &
  fi

  # Start QEMU in the foreground. This script will wait here until QEMU exits.
  start_qemu

  echo "[custom_startup.sh] QEMU process finished. Script exiting."

else
  # --- Run QEMU interactively via terminal ---
  echo "[custom_startup.sh] NOAUDIORDP is false. Launching interactive terminal for QEMU startup."

  # Pass the RDP fullscreen setting into the subshell environment
  # Use printf %q to safely quote the variable value for embedding in the command string
  RDPFULLSCREEN_Q=$(printf '%q' "$RDPFULLSCREEN")

  /usr/bin/xfce4-terminal --title="QEMU Startup" -x bash -c '
    # --- Commands below run inside the new terminal ---

    # Make RDPFULLSCREEN variable available inside this bash instance
    export RDPFULLSCREEN=${RDPFULLSCREEN_Q}

    # Import the functions (already exported by parent)
    # Alternatively, redefine them here if export doesn t work reliably across terminal launch
    # declare -f start_qemu
    # declare -f start_rdp_fullscreen

    echo "-----------------------------------------------------"
    echo " PulseAudio ready."
    echo " IMPORTANT: Click in the main Kasm window first"
    echo "            to ensure audio stream is active."
    echo " Afterwards, press Enter in THIS terminal window"
    echo "            to proceed with QEMU startup."
    echo "-----------------------------------------------------"
    read -p "Press Enter to start QEMU..."

    # Start RDP logic in the background *if* enabled, before starting QEMU
    if [[ "$RDPFULLSCREEN" == "true" ]]; then
        echo "[Terminal] RDPFULLSCREEN is true. Launching RDP wait loop in background."
        start_rdp_fullscreen &
    fi

    # Start QEMU in the foreground of this terminal
    start_qemu

    # Add a final read to keep the terminal open until user manually closes it,
    # so they can see any final messages or errors.
    read -p "QEMU exited. Press Enter to close this terminal window..."' 
  # --- End of commands for bash -c ---

  echo "[custom_startup.sh] Launched QEMU startup terminal. This script is now exiting."

fi

#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     vidcoderr_encoder.sh
# Description:  Encode queue file for Vidcoderr
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Read vidcoderr.ini file
source /usr/local/bin/vidcoderr/vidcoderr.ini

# Check for queue file
if ! [ -f ${QUEUE_FILE} ]; then
  echo "Fail: ${QUEUE}Usage: $0 cmd ..."
  exit -1;
fi

#---- Static Variables -------------------------------------------------------------

OTHER_EXT_FILTER=$(cat ${APP_HOME}/other_format_filter.txt | sed -e '/log$/d' | sed '/^$/d')

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

while [ -s ${QUEUE_FILE} ]; do
# ---- Read queue file and set ARGS
  # Set encoder ARGS
  IFS=',' read ARG1 ARG2 ARG3 ARG4 ARG5 ARG6 <<< read line < ${QUEUE_FILE}
  SRC_FILE="$ARG1"
  ENCODE_ARGS="$ARG2"
  FILE_PARENT_DIR="$ARG3"
  SRC_CATEGORY="$ARG4"
  ENCODE_OUTPUT_FILENAME="$ARG5"
  DST_DIR="$ARG6"

  # Validate SRC file ( delete queue entry if not valid)
  if ! [[ -f "${SRC_FILE}" ]]; then
    sed -i "1 d" ${QUEUE_FILE}
    continue
  fi

  # Delete current queue line
  sed -i "1 d" ${QUEUE_FILE}

  # DST Video filename
  ENCODE_OUTPUT_FILENAME_EXT="${ENCODE_OUTPUT_FILENAME##*.}"
  ENCODE_OUTPUT_FILENAME_SHORT="$(echo ${ENCODE_OUTPUT_FILENAME} | sed -e 's/([^()]*)//g' | sed 's/\[[^][]*\]//g' | sed -e 's/ \.\([a-z0-9]*\)$/\.\1/' | sed -e 's/\(.[a-z0-9]*$\)//')"

  # # SRC base dir
  # DST_FILE_BASEDIR="$(echo "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}" | sed "s|${TRANSCODE_DIR}/${SRC_CATEGORY}/||g")"

  # Make encoder dir
  mkdir -p "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}" # required for stream source media

# ---- Run Other-transcode
  cd "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}" && other-transcode ${ENCODE_ARGS} "${SRC_FILE}"
  sleep 1
  cd "${TRANSCODE_DIR}"

# ---- Post-process encoded files
  # Delete old matching files from destination folder
  rm -r -f ""${DST_DIR}"${ENCODE_OUTPUT_FILENAME_SHORT}.*" &>/dev/null

  # Video meta
  VIDEO_CODEC=$(mediainfo --Inform="Video;%Format%" "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}${ENCODE_OUTPUT_FILENAME}")
  AUDIO_CODEC=$(mediainfo --Inform="Audio;%Format%" "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}${ENCODE_OUTPUT_FILENAME}" | sed 's/[-]//g')
  AUDIO_CHANNELS=$(ffprobe -v error -show_entries stream=channel_layout -of default=nk=1:nw=1 "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}${ENCODE_OUTPUT_FILENAME}")
  height_var=$(mediainfo --Inform="Video;%Height%" "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}${ENCODE_OUTPUT_FILENAME}")
  if ((1<=$height_var && $height_var<=400)); then    
      VIDEO_RES='LOW Q'
  elif ((401<= $height_var && $height_var<=660)); then
      VIDEO_RES='480p'
  elif ((661<= $height_var && $height_var<=890)); then
      VIDEO_RES=='720p'
  elif ((891<= $height_var && $height_var<=1200)); then
      VIDEO_RES='1080p'
  else
      VIDEO_RES='HQ'
  fi
  DST_VIDEO_META="[${VIDEO_RES} ${VIDEO_CODEC} ${AUDIO_CODEC} ${AUDIO_CHANNELS^}]"

  # Rename and move files
  while read line; do
    if [[ $line == "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}${ENCODE_OUTPUT_FILENAME}" ]]; then
    # echo hello
      # Rename video file
      DST_FILENAME="$(echo ${ENCODE_OUTPUT_FILENAME_SHORT} ${DST_VIDEO_META}.${ENCODE_OUTPUT_FILENAME_EXT})"
      mv "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}${ENCODE_OUTPUT_FILENAME}" "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}${DST_FILENAME}"
      # Move video file to destination
      rsync --remove-source-files --relative "${TRANSCODE_DIR}/${SRC_CATEGORY}/./${FILE_PARENT_DIR}${DST_FILENAME}" "${DST_DIR}"
    elif [[ "${OTHER_EXT_FILTER[*]}" =~ "${line##*.}" ]]; then
    # echo hello2
      # Detect subtitle language
      if [ $(echo $line | awk -F'.' '{print $(NF-1)}') == eng ] || [ $(echo $line | awk -F'.' '{print $(NF-1)}') == en ]; then
        # Rename file
        DST_FILENAME="$(echo ${ENCODE_OUTPUT_FILENAME_SHORT} ${DST_VIDEO_META}.eng.${line##*.})"
        mv "${line}" "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}${DST_FILENAME}"
        # Move video file to destination
        rsync --remove-source-files --relative "${TRANSCODE_DIR}/${SRC_CATEGORY}/./${FILE_PARENT_DIR}${DST_FILENAME}" "${DST_DIR}"
      else
        # Detect language
        sleep 5
        LANGS=$(trans -id "$(cat ${line} | sed '10,100!d' | sed '/^$/d' | sed '/^[0-9\<\-]/d' | awk '{ if ( length > x ) { x = length; y = $0 } }END{ print y }')" | grep -i 'ISO 639-3' | awk '{print $NF}')
        if [[ $? != 0 ]]; then
          LANGS='eng'
        fi
        # Rename file
        DST_FILENAME="$(echo ${ENCODE_OUTPUT_FILENAME_SHORT} ${DST_VIDEO_META}.${LANGS}.${line##*.})"
        mv "${line}" "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}${DST_FILENAME}"
        # Move video file to destination
        rsync --remove-source-files --relative "${TRANSCODE_DIR}/${SRC_CATEGORY}/./${FILE_PARENT_DIR}${DST_FILENAME}" "${DST_DIR}"
      fi
    fi
    # Delete old files
    rm "${line}" &> /dev/null
  done < <( ls "${TRANSCODE_DIR}/${SRC_CATEGORY}/${FILE_PARENT_DIR}${ENCODE_OUTPUT_FILENAME_SHORT}".* )

  # Delete empty folders from base encoder folder
  cd ${TRANSCODE_DIR} && find . -empty -type d -delete 2>/dev/null

  # Throttle the check
  sleep 5
done
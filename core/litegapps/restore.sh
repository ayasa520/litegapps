BASED=$BASED
CONFIG=$BASED/config
GAPPS_FILES=$BASED/files
GAPPS=$BASED/gapps
MODULES=$BASED/modules
MODULES_FILES=$BASED/modules_files
read_config(){
	getp "$1" $CONFIG
	}
for i in $GAPPS $GAPPS_FILES $MODULES $MODULES_FILES; do
[ ! -d $i ] && cdir $i
done
LIST_ARCH=`read_config restore.arch | sed "s/,/ /g"`
LIST_SDK=`read_config restore.sdk | sed "s/,/ /g"`
NAME=`read_config name`

printlog " "
printlog "        Restore $NAME"
printlog " "


NUM_6070=0
for D_ARCH in $LIST_ARCH; do
	for D_SDK in $LIST_SDK; do
		if [ -f $GAPPS_FILES/$D_ARCH/$D_SDK/$D_SDK.zip ]; then
			if [ -d $GAPPS/$D_ARCH/$D_SDK ]; then
				del $GAPPS/$D_ARCH/$D_SDK
				cdir $GAPPS/$D_ARCH/$D_SDK
			else
				cdir $GAPPS/$D_ARCH/$D_SDK
			fi
			NUM_6070=$((NUM_6070 +1 ))
			printlog "${NUM_6070}. Available •> <$GAPPS_FILES/$D_ARCH/$D_SDK/$D_SDK.zip>"
			printlog "     Extracting : $D_ARCH/$D_SDK.zip"
			unzip -o $GAPPS_FILES/$D_ARCH/$D_SDK/$D_SDK.zip -d $GAPPS/$D_ARCH/$D_SDK > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				printlog "     Extrating status : Successful"
			else
				printlog "     Extrating status : Failed !!"
				printlog "     SKIPPING $D_ARCH/$D_SDK - corrupted file"
				del $GAPPS_FILES/$D_ARCH/$D_SDK/$D_SDK.zip
				del $GAPPS/$D_ARCH/$D_SDK
				continue
			fi
			printlog " "
		else
		NUM_6070=$((NUM_6070 +1 ))
		printlog "${NUM_6070}. Downloading : $D_ARCH/$D_SDK.zip"
		if [ -d $GAPPS/$D_ARCH/$D_SDK ]; then
			del $GAPPS/$D_ARCH/$D_SDK
			cdir $GAPPS/$D_ARCH/$D_SDK
		else
			cdir $GAPPS/$D_ARCH/$D_SDK
		fi
       if [ -d $GAPPS_FILES/$D_ARCH/$D_SDK ]; then
       	del $GAPPS_FILES/$D_ARCH/$D_SDK 
       	cdir $GAPPS_FILES/$D_ARCH/$D_SDK 
       else
       	cdir $GAPPS_FILES/$D_ARCH/$D_SDK 
       fi
       curl --progress-bar -L -o $GAPPS_FILES/$D_ARCH/$D_SDK/$D_SDK.zip https://sourceforge.net/projects/litegapps/files/files-server/litegapps/$D_ARCH/$D_SDK/$D_SDK.zip/download
       if [  $? -eq 0 ]; then
       	printlog "     Downloading status : Successful"
       	printlog "     File size : $(du -sh $GAPPS_FILES/$D_ARCH/$D_SDK/$D_SDK.zip | cut -f1)"
       else
       	printlog "     Downloading status : Failed"
       	printlog "     ! SKIPPING $D_ARCH/$D_SDK - file not available"
       	del $GAPPS/$D_ARCH/$D_SDK
       	del $GAPPS_FILES/$D_ARCH/$D_SDK/$D_SDK.zip
       	continue
       fi
       unzip -o $GAPPS_FILES/$D_ARCH/$D_SDK/$D_SDK.zip -d $GAPPS/$D_ARCH/$D_SDK >/dev/null 2>&1
       if [ $? -eq 0 ]; then
       	printlog "     Unzip : $GAPPS_FILES/$D_ARCH/$D_SDK/$D_SDK.zip"
       	printlog "     unzip status : Successful"
       else
       	printlog "     Unzip : $GAPPS_FILES/$D_ARCH/$D_SDK/$D_SDK.zip"
       	printlog "     unzip status : Failed"
       	printlog "     SKIPPING $D_ARCH/$D_SDK - corrupted or invalid file"
       	del $GAPPS/$D_ARCH/$D_SDK
       	del $GAPPS_FILES/$D_ARCH/$D_SDK/$D_SDK.zip
       	continue
       fi
       
	fi
	done
done

# Recovery function for missing files from official packages
recovery_from_official() {
	local arch=$1
	local sdk=$2
	local official_url=$3

	printlog "- Recovery: Attempting to recover $arch/$sdk from official package"

	# Create temporary recovery directory
	local recovery_tmp="/tmp/litegapps_recovery_$$"
	mkdir -p "$recovery_tmp"

	# Download official package
	printlog "  Downloading official package..."
	if curl -L -o "$recovery_tmp/official.zip" "$official_url" >/dev/null 2>&1; then
		printlog "  Download successful"

		# Extract official package
		if unzip -q "$recovery_tmp/official.zip" -d "$recovery_tmp/extract/"; then
			printlog "  Extraction successful"

			# Extract files.tar.xz
			if [ -f "$recovery_tmp/extract/files/files.tar.xz" ]; then
				cd "$recovery_tmp/extract/files"
				if tar -xf files.tar.xz >/dev/null 2>&1; then
					printlog "  Archive extraction successful"

					# Copy to gapps directory
					if [ -d "$recovery_tmp/extract/files/$arch/$sdk" ]; then
						mkdir -p "$GAPPS/$arch/$sdk"
						cp -r "$recovery_tmp/extract/files/$arch/$sdk/"* "$GAPPS/$arch/$sdk/"
						printlog "  Recovery successful: $arch/$sdk"

						# Create corresponding zip file for consistency
						mkdir -p "$GAPPS_FILES/$arch/$sdk"
						cd "$GAPPS/$arch/$sdk"
						zip -r9 "$GAPPS_FILES/$arch/$sdk/$sdk.zip" * >/dev/null 2>&1
						printlog "  Created zip file: $GAPPS_FILES/$arch/$sdk/$sdk.zip"
					else
						printlog "  ERROR: $arch/$sdk directory not found in official package"
					fi
				else
					printlog "  ERROR: Failed to extract files.tar.xz"
				fi
			else
				printlog "  ERROR: files.tar.xz not found in official package"
			fi
		else
			printlog "  ERROR: Failed to extract official package"
		fi
	else
		printlog "  ERROR: Failed to download official package"
	fi

	# Cleanup
	rm -rf "$recovery_tmp"
	cd "$BASED"
}

# Special recovery for missing combinations
printlog " "
printlog "=== RECOVERY PHASE ==="
printlog "Checking for missing files and attempting recovery from official packages..."

# Check if arm/33 is missing and attempt recovery
if [[ "$LIST_ARCH" == *"arm"* ]] && [[ "$LIST_SDK" == *"33"* ]]; then
	if [ ! -d "$GAPPS/arm/33" ] || [ ! "$(ls -A $GAPPS/arm/33 2>/dev/null)" ]; then
		printlog "- arm/33 is missing, attempting recovery..."
		recovery_from_official "arm" "33" "https://sourceforge.net/projects/litegapps/files/litegapps/arm/33/lite/2024-08-15/AUTO-LiteGapps-arm-13.0-20240815-official.zip/download"
	else
		printlog "- arm/33 already exists, skipping recovery"
	fi
fi

# Check if x86_64/33 is missing and attempt recovery
if [[ "$LIST_ARCH" == *"x86_64"* ]] && [[ "$LIST_SDK" == *"33"* ]]; then
	if [ ! -d "$GAPPS/x86_64/33" ] || [ ! "$(ls -A $GAPPS/x86_64/33 2>/dev/null)" ]; then
		printlog "- x86_64/33 is missing, attempting recovery..."
		recovery_from_official "x86_64" "33" "https://sourceforge.net/projects/litegapps/files/litegapps/x86_64/33/lite/2024-02-24/AUTO-LiteGapps-x86_64-13.0-20240224-official.zip/download"
	else
		printlog "- x86_64/33 already exists, skipping recovery"
	fi
fi

printlog "=== RECOVERY PHASE COMPLETE ==="
printlog " "

NUM_6070=0
for D_ARCH in $LIST_ARCH; do
	for D_SDK in $LIST_SDK; do
		[ ! -d $BASED/$D_ARCH/$D_SDK ] && break
		for L_RESTORE in $(ls -1 $BASED/$D_ARCH/$D_SDK); do
			if [ -f $BASED/$D_ARCH/$D_SDK/$L_RESTORE ]; then
			F_RESTORE=$BASED/$D_ARCH/$D_SDK/$L_RESTORE
				for L_MODULES in $(cat $F_RESTORE); do
					if [ -f $MODULES/$D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip ]; then
						
						test ! -d $MODULES/$D_ARCH/$D_SDK/$L_RESTORE && cdir $MODULES/$D_ARCH/$D_SDK/$L_RESTORE
						test -f $MODULES/$D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip && del $MODULES/$D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip
						NUM_6070=$((NUM_6070 +1 ))
						printlog "${NUM_6070}. Available •> <$MODULES_FILES/$D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip>"
						printlog "     Moving : $D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip"
						cp -pf $MODULES_FILES/$D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip $MODULES/$D_ARCH/$D_SDK/$L_RESTORE
						printlog " "
					else
						NUM_6070=$((NUM_6070 +1 ))
						printlog "${NUM_6070}. Downloading : $D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip"
						test ! -d $MODULES/$D_ARCH/$D_SDK/$L_RESTORE && cdir $D_ARCH/$D_SDK/$L_RESTORE
						test ! -d $MODULES_FILES/$D_ARCH/$D_SDK/$L_RESTORE && cdir $MODULES_FILES/$D_ARCH/$D_SDK/$L_RESTORE
						test -f $MODULES_FILES/$D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip && del $MODULES_FILES/$D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip
       		 		#download
       		 		SERVER=https://sourceforge.net/projects/litegapps/files/addon/
       		 		curl --progress-bar -L -o $MODULES_FILES/$D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip $SERVER/$D_ARCH/$D_SDK/$L_RESTORE/$D_SDK.zip
       		 		if [  $? -eq 0 ]; then
       		 			printlog "     Downloading status : Successful"
       		 			printlog "     File size : $(du -sh $MODULES_FILES/$D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip | cut -f1)"
       	     		else
       	     			printlog "     Downloading status : Failed"
       	     			printlog "     ! PLEASE CEK YOUR INTERNET CONNECTION AND RESTORE AGAIN"
       	     			del $MODULES_FILES/$D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip
       	     			exit 1
       		 		fi
       		 		printlog "     Moving : $D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip"
       		 		cp -pf $MODULES_FILES/$D_ARCH/$D_SDK/$L_RESTORE/$L_MODULES.zip $MODULES/$D_ARCH/$D_SDK/$L_RESTORE
			 		fi
				done
			fi
		done
	done
done


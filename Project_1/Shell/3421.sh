#!/bin/sh

bname=$(basename "$0") ; dname=$(dirname "$0") ; usage=""$dname"/"$bname""

if [ "$#" -eq 1 -a -n "$1" ]; then
	# recursively calls itself with all ten file names
	if [ "$1" = "-a" ]; then
		"$usage" one two three four five six seven eight nine ten
		exit "$?";
	elif [ "$1" = "-av" ]; then
		"$usage" -v one two three four five six seven eight nine ten
		exit "$?";
	fi
fi

# working directory
wdir=$(pwd)
echo -e "Working Directory is: "$wdir"\n"

# if you are sane enough not to give yrb-create and/or yrb-drop as arguments to the script then
# set the following variable ('sane') to a non-zero integer so that the script doesn't check for you
sane=1
[ "$sane" -ne 0 ] && echo -e "You are claiming to be sane enough!\n"

trim_qout_file() {
	if [ "$#" -ne 1 -o -z "$1" -o ! -f "$1" ]; then
		return -1;
	fi
	sed -i '1,3d' "$1"
	temp=$(sed '$d' "$1" | sed '$d')
	yes | rm -f "$1" > /dev/null && echo "$temp" > "$1"
	return 0;
}

if [ "$#" -eq 0 ]; then
	echo -e "Usage:\n"$usage" sql_script(s)\nOR\n"$usage" -v sql_script(s)\nOR\n"$usage" -a\nOR\n"$usage" -av"
	exit 1;
fi

miss=0
if [ ! -f yrb-create ]; then
	echo "Missing: SQL script with name yrb-create"
	miss=`expr "$miss" + 1`
fi
if [ ! -f yrb-drop ]; then
	echo "Missing: SQL script with name yrb-drop"
	miss=`expr "$miss" + 1`
fi
[ "$miss" -ne 0 ] && exit `expr "$miss" + 1`;

verbose=0
if [ "$1" = "-v" ]; then
	verbose=1 ; shift 1
fi

num=0 ; pass=0 ; fail=0 ; cmp_error=0

db2 connect to c3421a > /dev/null
db2 -tf yrb-create > /dev/null
while [ "$#" -ne 0 ]; do
	sql=$1 ; shift 1

	if [ -z "$sql" ]; then
		continue;
	elif [ ! -f "$sql" ]; then
		echo "Missing: SQL script with name "$sql""
		continue;
	fi

	if [ "$sane" -eq 0 ]; then
		cmp -s "$sql" yrb-create ; ret="$?"
		if [ "$ret" -eq 0 ]; then
			echo ""$sql" = yrb-create"
			continue;
		elif [ "$ret" -ne 1 ]; then
			echo "yrb-create: CMP ERROR "$ret""
			continue;
		fi

		cmp -s "$sql" yrb-drop ; ret="$?"
		if [ "$ret" -eq 0 ]; then
			echo ""$sql" = yrb-drop"
			continue;
		elif [ "$ret" -ne 1 ]; then
			echo "yrb-drop: CMP ERROR "$ret""
			continue;
		fi
	fi

	if [ -f ""$sql"_out.txt" ]; then
		echo -n "Overwrite "$sql"_out.txt? (y/n): "
		read ans

		overwrite=0
		if [ -n "$ans" ]; then
			if [ "$ans" = "y" -o "$ans" = "Y" -o "$ans" = "yes" -o "$ans" = "Yes" -o "$ans" = "YES" ]; then
				overwrite=1
			fi
		fi
		if [ "$overwrite" -eq 0 ]; then
			echo -e "Regular file with name "$sql"_out.txt already exists.\nPlease rename/remove it."
			continue;
		fi
	fi
	[ -f ""$sql"_out.txt" ] && yes | rm -f ""$sql"_out.txt" > /dev/null

	db2 -tf "$sql" > ""$sql"_out.txt"
	ret=$(trim_qout_file ""$sql"_out.txt") # will never get non-zero return
	if [ "$verbose" -eq 1 ]; then
		[ -f ""$sql"_out_verbose.txt" ] && yes | rm -f ""$sql"_out_verbose.txt" > /dev/null
		db2 -tvf "$sql" > ""$sql"_out_verbose.txt"
	fi
	echo "Finished running SQL script with name "$sql""

	if [ -f ""$sql"_answertable.txt" ]; then
		cmp -s ""$sql"_out.txt" ""$sql"_answertable.txt" ; ret="$?"
		if [ "$ret" -eq 0 ]; then
			echo "PASS: "$sql""
			pass=`expr "$pass" + 1`
		elif [ "$ret" -eq 1 ]; then
			echo "FAIL: "$sql""
			fail=`expr "$fail" + 1`
		else
			echo ""$sql"_answertable: CMP ERROR "$ret""
			cmp_error=`expr "$cmp_error" + 1`
		fi
		num=`expr "$num" + 1`
	fi
done
db2 -tf yrb-drop > /dev/null
db2 connect reset > /dev/null
db2 terminate > /dev/null

if [ "$num" -ne 0 ]; then
	echo -e "\nPASSED: "$pass"/"$num", FAILED: "$fail"/"$num", CMP_ERRORS: "$cmp_error"/"$num""
fi

exit 0;

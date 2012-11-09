#!/bin/sh


PREFIX=/usr/local


if [ "x$1" = "x" ] || [ "x$1" = "x--help" ] ; then
    echo "usage: $0 [OPTION]... package [VERSION]";
    cat <<EOF
Select a specific version of McStas/McXtrace as default.

  --list     list available versions of package.
  --install  install a new version of package for later linking.
  --dryrun   run checks and simulate actions only.
  --help     display this help and exit.

Report bugs to jsbn@fysik.dtu.dk
EOF
    exit 0;
fi


# Parse arguments
LIST=false;
INSTALL=false;
DOIT=true;

while true; do
    case "$1" in
        "--install" )
            INSTALL=true;
            ;;
        "--list" )
            LIST=true
            ;;
        "--dryrun" )
            DOIT=false;
            ;;
        * )
            # No match, drop out
            break;
    esac
    shift;
done

if ${LIST} && ${INSTALL}; then
    echo "Error: list and install cannot be combined. Pick one.";
    exit 1;
fi

# Set name and version
NAME="$1"
VERSION="$2"


# Check to see whether we have update-alternatives (Debian)
ALTERNATIVES=$(command -v update-alternatives)
if [ $? -eq 0 ] && [ -x ${ALTERNATIVES} ]; then
    HAS_ALTERNATIVES=true;
else
    HAS_ALTERNATIVES=false;
fi


function list() {
    (
        cd "${PREFIX}/bin";
        for ver in "${NAME}-"*; do
            echo "${ver}" | sed s/\-/': '/;
        done
    )
}


function flavor() {
    case "$1" in
        "mcstas" )
            echo "mc";
            ;;
        "mcxtrace" )
            echo "mx";
            ;;
    esac
}

function whenReal() {
    if ${DOIT}; then
        $*
    fi
}


function doLink() {
    (
        FROM="$1"
        TO="$2"

        if [ -L "${TO}" ]; then
            rm "${TO}";
        fi

        if [ -e "${TO}" ]; then
            echo "Error: cannot replace existing file: ${TO}";
            exit 1;
        fi

        ln -vs "${FROM}" "${TO}" ;
    )
}

function installBinary() {
    (
        name="$1"
        vers="$2"
        targ="$3"

        link="${PREFIX}/bin/${name}"
        file="${link}-${vers}"

        prio="`echo ${vers} | sed 's/\./ * 10000 + /' | bc`"
        if [ $? -ne 0 ]; then
            prio=1;
        fi

        if ! [ -x "${file}" ]; then
            echo "Error: could not locate binary: ${PREFIX}/${file}"
            exit 1;
        else
            MANCMD=""
            manlink="${PREFIX}/man/man1/${name}.1"
            manfile="${PREFIX}/man/man1/${name}-${vers}.1"
            if [ -f "${manfile}" ]; then
                MANCMD="--slave ${manlink} ${name}.1 ${manfile}"
            fi

            # Install using update alternatives
            if ${HAS_ALTERNATIVES}; then
                echo "INSTALL: ${name}: ${file}"
                whenReal ${ALTERNATIVES} --install \
                    "${link}" "${name}" "${file}" ${prio} \
                    ${MANCMD} ;
            fi

            # When update-alternatives is not present --install only checks
        fi
    )
}

function linkBinary() {
    (
        cd "${PREFIX}";

        name="$1";
        vers="$2"

        link="${PREFIX}/bin/${name}";
        file="${link}-${vers}";

        if ! [ -x "${file}" ]; then
            echo "Error: could not locate binary: ${file}"
            exit 1;
        else
            if ${HAS_ALTERNATIVES}; then
                echo "${name} -> ${file}"
                whenReal ${ALTERNATIVES} --set "${name}" "${file}"
                exit 0;
            else
                whenReal doLink "${file}" "${link}"
            fi
        fi

        # Man pages are auto linked when using update-alternatives
        # The below is for manual linking only

        link="${PREFIX}/man/man1/${name}.1";
        file="${PREFIX}/man/man1/${name}-${vers}.1";

        if [ -f "${file}" ]; then
            whenReal doLink "${file}" "${link}";
        fi

    )
}


if ${LIST}; then
    list "${NAME}"
else
    if ${INSTALL}; then
        installBinary "${NAME}" "${VERSION}"
    else
        linkBinary "${NAME}" "${VERSION}"
    fi
fi

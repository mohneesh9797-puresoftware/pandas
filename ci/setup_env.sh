#!/bin/bash -e

# edit the locale file if needed
if [[ "$(uname)" == "Linux" && -n "$LC_ALL" ]]; then
    echo "Adding locale to the first line of pandas/__init__.py"
    rm -f pandas/__init__.pyc
    SEDC="3iimport locale\nlocale.setlocale(locale.LC_ALL, '$LC_ALL')\n"
    sed -i "$SEDC" pandas/__init__.py

    echo "[head -4 pandas/__init__.py]"
    head -4 pandas/__init__.py
    echo
fi

MINICONDA_DIR="$HOME/miniconda"


if [ -d "$MINICONDA_DIR" ]; then
    echo
    echo "rm -rf "$MINICONDA_DIR""
    rm -rf "$MINICONDA_DIR"
fi

echo "Install Miniconda"
UNAME_OS=$(uname)
if [[ "$UNAME_OS" == 'Linux' ]]; then
    if [[ "$BITS32" == "yes" ]]; then
        CONDA_OS="Linux-x86"
    else
        CONDA_OS="Linux-x86_64"
    fi
elif [[ "$UNAME_OS" == 'Darwin' ]]; then
    CONDA_OS="MacOSX-x86_64"
else
  echo "OS $UNAME_OS not supported"
  exit 1
fi

if [[ "${TRAVIS_CPU_ARCH}" == "arm64" ]]; then
           export ISSUDO=sudo;
           wget -q "https://github.com/Archiconda/build-tools/releases/download/0.2.3/Archiconda3-0.2.3-Linux-aarch64.sh" -O archiconda.sh;
           chmod +x archiconda.sh;
           bash archiconda.sh -b -p $HOME/miniconda;
           export PATH="$HOME/miniconda/bin:$PATH";
           $ISSUDO cp -r $HOME/miniconda/bin/* /usr/bin/;
        else
           wget http://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh;
           bash miniconda.sh -b -p $HOME/miniconda;  
        fi
export PATH=$MINICONDA_DIR/bin:$PATH

echo
echo "which conda"
which conda

echo
echo "update conda"
$ISSUDO conda config --set ssl_verify false
$ISSUDO conda config --set quiet true --set always_yes true --set changeps1 false
$ISSUDO conda install pip  # create conda to create a historical artifact for pip & setuptools
$ISSUDO conda update -n base conda

echo "conda info -a"
conda info -a

echo
echo "set the compiler cache to work"
if [ -z "$NOCACHE" ] && [ "${TRAVIS_OS_NAME}" == "linux" ]; then
    echo "Using ccache"
    export PATH=/usr/lib/ccache:/usr/lib64/ccache:$PATH
    GCC=$(which gcc)
    echo "gcc: $GCC"
    CCACHE=$(which ccache)
    echo "ccache: $CCACHE"
    export CC='ccache gcc'
elif [ -z "$NOCACHE" ] && [ "${TRAVIS_OS_NAME}" == "osx" ]; then
    echo "Install ccache"
    brew install ccache > /dev/null 2>&1
    echo "Using ccache"
    export PATH=/usr/local/opt/ccache/libexec:$PATH
    gcc=$(which gcc)
    echo "gcc: $gcc"
    CCACHE=$(which ccache)
    echo "ccache: $CCACHE"
else
    echo "Not using ccache"
fi

echo "source deactivate"
source deactivate

echo "conda list (root environment)"
conda list

# Clean up any left-over from a previous build
# (note workaround for https://github.com/conda/conda/issues/2679:
#  `conda env remove` issue)
conda remove --all -q -y -n pandas-dev

echo
echo "conda env create -q --file=${ENV_FILE}"

if [[ "${TRAVIS_CPU_ARCH}" == "arm64" ]]; then
   
echo;
$IS_SUDO chmod -R 777 $MINICONDA_DIR;
$IS_SUDO apt-get install xvfb;
$IS_SUDO conda install botocore;
$IS_SUDO conda install python-dateutil=2.8.0;
$IS_SUDO conda install pytz;
$IS_SUDO chmod -R 777 $MINICONDA_DIR;

echo "conda env create -q --file=${ENV_FILE}"
time $IS_SUDO conda env create -q --file="${ENV_FILE}"
else
   time $ISSUDO conda env create -q --file="${ENV_FILE}";
fi
        
if [[ "$BITS32" == "yes" ]]; then
    # activate 32-bit compiler
    export CONDA_BUILD=1
fi

echo "activate pandas-dev"
source activate pandas-dev

echo
echo "remove any installed pandas package"
echo "w/o removing anything else"
conda remove pandas -y --force || true
$SUDO pip uninstall -y pandas || true

echo
echo "remove postgres if has been installed with conda"
echo "we use the one from the CI"
conda remove postgresql -y --force || true

echo
echo "remove qt"
echo "causes problems with the clipboard, we use xsel for that"
conda remove qt -y --force || true

echo
echo "conda list pandas"
conda list pandas

# Make sure any error below is reported as such

echo "[Build extensions]"
$SUDO python setup.py build_ext -q -i -j2

# XXX: Some of our environments end up with old versions of pip (10.x)
# Adding a new enough version of pip to the requirements explodes the
# solve time. Just using pip to update itself.
# - py35_macos
# - py35_compat
# - py36_32bit
echo "[Updating pip]"
$SUDO python -m pip install --no-deps -U pip wheel setuptools

echo "[Install pandas]"
$SUDO python -m pip install --no-build-isolation -e .

echo
echo "conda list"
conda list

# Install DB for Linux

if [[ -n ${SQL:0} ]]; then
  echo "installing dbs"
  mysql -e 'create database pandas_nosetest;'
  psql -c 'create database pandas_nosetest;' -U postgres
else
   echo "not using dbs on non-linux Travis builds or Azure Pipelines"
fi

echo "done"

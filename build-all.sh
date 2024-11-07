#!/bin/sh

# TODO
# * add db content
# /TODO

#set -o pipefail

global_prefix="/opt/cmangos-bundle"
tmp_install_prefix="/tmp/cmangos-install"
boost_version="1_79_0"
cmake_version="3.23.2"
openssl_version="3.4.0"
gcc_compiler="/opt/gcc-latest/bin/gcc"
cpp_compiler="/opt/gcc-latest/bin/cpp"
release_date=$(timeout 5 curl -s --connect-timeout 2 https://github.com/cmangos/mangos-classic/releases/tag/latest | egrep -o 'Release Development Build\(....-..-..\)' | uniq | egrep -o '....-..-..')
if [ -z ${release_date} ]
then
	echo "Cannot get current release date"
	exit 1
fi
cmangos_name="cmangos-classic-${release_date}"
dotted_cmangos_name="cmangos-classic-$(echo ${release_date} | tr '-' '.')"
database_version="latest"
log_file="build-all.log"

work_dir=$(pwd)
> ${work_dir}/${log_file}

# got my compiler from https://jwakely.github.io/pkg-gcc-latest/, converted using deb2tgz and installed into system"
echo "Checking compiler presence and version"
gcc_compiler_not_found="no"
test -x ${gcc_compiler} || gcc_compiler_not_found="yes"
if [ "${cpp_compiler_not_found}" == "yes" ]
then
	echo "No custom GCC compiler found"
	exit 1
else
	echo "Found ${gcc_compiler}"
fi
cpp_compiler_not_found="no"
test -x ${cpp_compiler} || cpp_compiler_not_found="yes"
if [ "${cpp_compiler_not_found}" == "yes" ]
then
	echo "No custom CPP compiler found"
	exit 1
else
	echo "Found ${cpp_compiler}"
fi
compiler_version=$(${gcc_compiler} --version | grep ^gcc | cut -d' ' -f3 | cut -d'.' -f1)
if [ ${compiler_version} -lt 12 ]
then
	echo "Need GCC 12 or more"
	exit 1
else
	echo "Compiler version is ${compiler_version}"
fi

echo "Checking 'build' directory presence"
test -d build || mkdir build
cd build

# see boost vs cmake compatibility table
# https://github.com/cmangos/issues/wiki/CMake-to-Boost-Version-Compatibility-Table

echo -n "Checking temporary install directory presence - "
test -d ${tmp_install_prefix} || mkdir ${tmp_install_prefix}

# build boost

echo "Downloading boost"
test -f boost_${boost_version}.tar.bz2 || wget -q https://archives.boost.io/release/$(echo ${boost_version} | tr '_' '.')/source/boost_${boost_version}.tar.bz2
test -d boost_${boost_version} || tar xfj boost_${boost_version}.tar.bz2
cd boost_${boost_version}
echo "Booststrapping boost"
./bootstrap.sh --prefix=${global_prefix}/boost >> ${work_dir}/${log_file} 2>&1
result=${?}
if [ ${result} -ne 0 ]
then
	echo "Shit happened, see ${work_dir}/${log_file}"
	exit 1
fi
echo "Compiling and installing boost to temporary location"
./b2 --prefix=${tmp_install_prefix}${global_prefix}/boost install >> ${work_dir}/${log_file} 2>&1
result=${?}
if [ ${result} -ne 0 ]
then
	echo "Shit happened, see ${work_dir}/${log_file}"
	exit 1
fi
cd -


# setup cmake

echo "Downloading cmake binaries"
test -f cmake-${cmake_version}-linux-x86_64.tar.gz || wget -q https://github.com/Kitware/CMake/releases/download/v${cmake_version}/cmake-${cmake_version}-linux-x86_64.tar.gz
test -d cmake-${cmake_version}-linux-x86_64 || tar xfz cmake-${cmake_version}-linux-x86_64.tar.gz


# build openssl

echo "Downloading openssl"
test -f openssl-${openssl_version}.tar.gz || wget -q https://github.com/openssl/openssl/releases/download/openssl-${openssl_version}/openssl-${openssl_version}.tar.gz
test -d openssl-${openssl_version} || tar xfz openssl-${openssl_version}.tar.gz
cd openssl-${openssl_version}
echo "Configuring openssl"
./Configure --prefix=${global_prefix}/openssl > ${work_dir}/${log_file} 2>&1
result=${?}
if [ ${result} -ne 0 ]
then
	echo "Shit happened, see ${work_dir}/${log_file}"
	exit 1
fi
echo "Compiling openssl"
make >> ${work_dir}/${log_file} 2>&1
result=${?}
if [ ${result} -ne 0 ]
then
	echo "Shit happened, see ${work_dir}/${log_file}"
	exit 1
fi
echo "Installing openssl to temporary location"
make DESTDIR=${tmp_install_prefix} install >> ${work_dir}/${log_file} 2>&1
result=${?}
if [ ${result} -ne 0 ]
then
	echo "Shit happened, see ${work_dir}/${log_file}"
	exit 1
fi
cd -


# get cmangos sources

echo "Downloading cmangos"
test -f ${cmangos_name}.tar.gz || wget -q https://github.com/cmangos/mangos-classic/archive/refs/tags/latest.tar.gz -O ${cmangos_name}.tar.gz
test -d ${cmangos_name} || mkdir ${cmangos_name}
test -f ${cmangos_name}/README.md || tar xfz ${cmangos_name}.tar.gz -C ${cmangos_name} --strip-components 1
test -d ${cmangos_name}/build || mkdir -p ${cmangos_name}/build
cd ${cmangos_name}/build

# build all together
echo "Configuring cmangos"
CC=/opt/gcc-latest/bin/gcc \
CXX=/opt/gcc-latest/bin/g++ \
../../cmake-${cmake_version}-linux-x86_64/bin/cmake \
	-DCMAKE_INSTALL_PREFIX=${global_prefix}/cmangos \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=1 \
	-DBUILD_METRICS=1 \
	-DPCH=1 \
	-DDEBUG=0 \
	-DBUILD_PLAYERBOTS=ON \
	-DBUILD_GAME_SERVER=ON \
	-DBUILD_LOGIN_SERVER=ON \
	-DBUILD_EXTRACTORS=ON \
	-DBUILD_AHBOT=ON \
	-DBoost_DEBUG=ON \
	-DBOOST_ROOT=${tmp_install_prefix}${global_prefix}/boost \
	-DOPENSSL_ROOT_DIR=${tmp_install_prefix}${global_prefix}/openssl \
	-DBoost_NO_BOOST_CMAKE=TRUE \
	-Wno-dev \
	../ >> ${work_dir}/${log_file} 2>&1
result=${?}
if [ ${result} -ne 0 ]
then
	echo "Shit happened, see ${work_dir}/${log_file}"
	exit 1
fi
echo "Compiling cmangos using ${gcc_compiler}, openssl-${openssl_version}, boost-${boost_version} and cmake-${cmake_version}"
make -j $(grep -c ^processor /proc/cpuinfo) >> ${work_dir}/${log_file} 2>&1  
result=${?}
if [ ${result} -ne 0 ]
then
	echo "Shit happened, see ${work_dir}/${log_file}"
	exit 1
fi

echo "Installing cmangos to temporary location"
make DESTDIR=${tmp_install_prefix} install >> ${work_dir}/${log_file} 2>&1 
result=${?}
if [ ${result} -ne 0 ]
then
	echo "Shit happened, see ${work_dir}/${log_file}"
	exit 1
fi

echo "Adding acustom content"
mkdir -p ${tmp_install_prefix}/var/log/cmangos 
mkdir -p ${tmp_install_prefix}/var/run/cmangos 
mkdir -p ${tmp_install_prefix}/etc/default
mkdir -p ${tmp_install_prefix}/etc/rc.d
mkdir -p ${tmp_install_prefix}/${global_prefix}/cmangos/data
mkdir -p ${tmp_install_prefix}/install
cat ${work_dir}/etc-default-cmangos > ${tmp_install_prefix}/etc/default/cmangos.new
sed -e 's|^LogsDir = ""|LogsDir = "/var/log/cmangos"|' -i ${tmp_install_prefix}${global_prefix}/cmangos/etc/mangosd.conf.dist
sed -e 's|^PidFile = ""|PidFile = "/var/run/cmangos/mangosd.pid"|' -i ${tmp_install_prefix}${global_prefix}/cmangos/etc/mangosd.conf.dist
sed -e 's|^LogsDir = ""|LogsDir = "/var/log/cmangos"|' -i ${tmp_install_prefix}${global_prefix}/cmangos/etc/realmd.conf.dist
sed -e 's|^PidFile = ""|PidFile = "/var/run/cmangos/realmd.pid"|' -i ${tmp_install_prefix}${global_prefix}/cmangos/etc/realmd.conf.dist
sed -e 's|^DataDir = "."|DataDir = "/opt/cmangos-bundle/cmangos/data"|' -i ${tmp_install_prefix}${global_prefix}/cmangos/etc/mangosd.conf.dist
install -m 755 ${work_dir}/rc.mangosd.in ${tmp_install_prefix}/etc/rc.d/rc.mangosd.new
install -m 755 ${work_dir}/rc.realmd.in ${tmp_install_prefix}/etc/rc.d/rc.realmd.new
install -m 0700 ${work_dir}/doinst.sh.in ${tmp_install_prefix}/install/doinst.sh
install -m 0644 ${work_dir}/slack-desc ${tmp_install_prefix}/install/slack-desc
cd ${work_dir}/build

# Database files
echo "Downloading database setup files"
test -f classic-db-${database_version}.tar.gz || wget -q https://github.com/cmangos/classic-db/archive/refs/tags/${database_version}.tar.gz -O classic-db-${database_version}.tar.gz
test -d classic-db-${database_version} || tar xfz classic-db-${database_version}.tar.gz
test -d classic-db-${database_version}/.github && rm -rf classic-db-${database_version}/.github
mkdir -p ${tmp_install_prefix}${global_prefix}/cmangos/etc/sql
# cleanup some unneeded shit
rm -rf ${tmp_install_prefix}${global_prefix}/boost/include
rm -rf ${tmp_install_prefix}${global_prefix}/boost/lib/cmake
rm -rf ${tmp_install_prefix}${global_prefix}/openssl/share/
rm -rf ${tmp_install_prefix}${global_prefix}/openssl/include

# copy database stuff
cp -r classic-db-${database_version}/* ${tmp_install_prefix}${global_prefix}/cmangos/etc/sql/
result=${?}
if [ ${result} -ne 0 ]
then
	echo "Shit happened, see ${work_dir}/${log_file}"
	exit 1
fi

# strip binaries
echo "Stripping binaries"
find "${tmp_install_prefix}${global_prefix}/" | xargs file | grep "executable" | grep ELF | cut -f 1 -d : | xargs strip -v --strip-unneeded 2> /dev/null
find "${tmp_install_prefix}${global_prefix}/" | xargs file | grep "shared object" | grep ELF | cut -f 1 -d : | xargs strip -v --strip-unneeded 2> /dev/null

cd ${tmp_install_prefix}
echo "Creating package"
echo "Running privileged actions, need password"
sudo chown -R root:root ${tmp_install_prefix}
sudo /sbin/makepkg -l y -c n --remove-tmp-rpaths --remove-rpaths ${work_dir}/${dotted_cmangos_name}-x86_64-1.txz
cd ${work_dir}
echo "All done"

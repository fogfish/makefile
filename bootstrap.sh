##
## Copyright (C) 2012 Dmitry Kolesnikov
##
## This bootstrap script may be modified and distributed under the terms
## of the MIT license.  See the LICENSE file for details.
## https://github.com/fogfish/makefile
##
## @doc
##    node deployment script
##       ${PREFIX} - root installation folder
##       ${REL}    - absolute path to release
##       ${APP}    - application name
##       ${VSN}    - application version
##
## @version 1.0.0
set -u
set -e

##
## discover version of erlang release
VERSION=`cat ${REL}/releases/start_erl.data`
SYS_VSN=${VERSION% *}
APP_VSN=${VERSION#* }


##
## make alias to current version
rm -f ${PREFIX}/${APP}
ln -s ${PREFIX}/${APP}-${VSN} ${PREFIX}/${APP}


##
## build service wrapper
if [[ $(uname -s) == "Linux" ]] ;
then

cat > /etc/init.d/${APP} <<- EOF
#!/bin/sh
export HOME=/root

FILE=${REL}/releases/${APP_VSN}/vm.args
HOST=\$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/local-ipv4)
if [ -z "\${HOST}" ] ;
then
HOST=\$({ ip addr show eth0 | sed -n 's/.*inet \([0-9]*.[0-9]*.[0-9]*.[0-9]*\).*/\1/p' ; } || echo "127.0.0.1")
fi

NODE=\$(sed -n -e "s/-name \(.*\)@.*/\1/p" \${FILE})
sed -i -e "s/@\(127.0.0.1\)/@\${HOST}/g" \${FILE}

${PREFIX}/${APP}/bin/${APP} \$1
EOF
   
chmod ugo+x /etc/init.d/${APP}
ln -s /etc/init.d/${APP} /etc/init.d/application

fi

set +u
set +e

## EOF

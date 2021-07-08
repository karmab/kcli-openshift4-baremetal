# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi
export KUBECONFIG=/root/ocp/auth/kubeconfig
export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE={{ openshift_image }}
export OS_CLOUD=metal3-bootstrap
export OS_ENDPOINT=http://172.22.0.2:6385
export PATH=/usr/local/bin:/root/bin:$PATH
export LIBVIRT_DEFAULT_URI=qemu+ssh://{{ 'root' if config_user == 'apache' else config_user }}@{{ config_host if config_host != '127.0.0.1' else baremetal_net|local_ip(true) }}/system
export REGISTRY_PASSWORD={{ disconnected_password }}
export REGISTRY_USER={{ disconnected_user }}
export SPOKE={{ acm_spoke_name if acm else "" }}

## Purpose

This repository provides automation for deploying the following components:

- a hub cluster using Agent Based Install
- spokes using ZTP

## Architecture 

Kcli is leveraged to deploy a plan which creates an "installer vm" to drive deployment via the following steps:

- Virtual nodes for both the hub and spokes are created (or combined with baremetal nodes). Note this is optional
- Client packages such as openshift-install are downloaded with any specified version and tag.
- Stop the nodes to deploy through redfish.
- Launch hub install against them
- Install ZTP requirements such as assisted service, openshift-gitops, a git server, ... 
- Launch spoke deployments

Parameters allow to customize the installation

The installer vm (and additional virtual nodes) can run on any platform supported by kcli with support for iso deployment.
So far it was tested on:

- kvm
- vsphere and esx

### Requirements

#### for kcli

- kcli installed (for rhel8/cento8/fedora, look [here](https://kcli.readthedocs.io/en/latest/#package-install-method))
- An openshift pull secret (stored by default in openshift_pull.json)

#### on the provisioning node (KVM Only)

- a physical bridge typically named baremetal with a nic from the external network

Here's a script you can run on the provisioning node for that (adjust the NIC variable as per your environment)

```
export NIC=eno2
sudo nmcli connection add ifname baremetal type bridge con-name baremetal
sudo nmcli con add type bridge-slave ifname $NIC master baremetal
sudo nmcli con down $NIC; sudo pkill dhclient; sudo dhclient baremetal
```

## Launch

Prepare a valid parameter file with the information needed. At least, you need to specify the following elements:

- api_ip
- ingress_ip
- bmc_user/bmc_password (for real baremetal)
- an array of your ctlplanes (if thet are not virtual). Each entry in this array needs at least the provisioning_mac and redfish_address. Optionally you can indicate for each entry a specific bmc_user, bmc_password and disk (to be used as rootdevice hint) either as /dev/XXX or simply XXX
- an array of your workers (can be left empty if you only want to deploy ctlplanes). The format of those entries follow the one indicated for ctlplanes.

Here's a snippet what the workers variable might look like:

```
workers:
- redfish_address: 192.168.1.5
- redfish_address: 192.168.1.6
```

You can have a look at:

- [parameters.yml](samples/parameters.yml) for a parameter file targetting baremetal nodes only
- [parameters_virtual.yml](samples/parameters_virtual.yml) for one combining virtual ctlplanes and physical workers.

Call the resulting file `kcli_parameters.yml` to avoid having to specify it in the creation command.

Then you can launch deployment with:

```
kcli create plan
```

## Interacting in the vm

```
kcli ssh
```

## Parameters

### virtual infrastructure only parameters

Note that you can use the baseplan `kcli_plan_infra.yml` to deploy the infrastructure only

|Parameter                           |Default Value   |
|------------------------------------|--------------  |
|api_ip                              |None            |
|baremetal\_bootstrap\_mac           |None            |
|baremetal_cidr                      |None            |
|baremetal_ips                       |[]              |
|baremetal_macs                      |[]              |
|baremetal_net                       |baremetal       |
|cluster                             |openshift       |
|disk_size                           |30              |
|domain                              |karmalabs.corp  |
|dualstack                           |False           |
|dualstack_cidr                      |None            |
|extra_disks                         |[]              |
|http_proxy                          |None            |
|ingress_ip                          |None            |
|keys                                |[]              |
|create_network                      |False           |
|memory                              |32768           |
|model                               |dell            |
|no_proxy                            |None            |
|numcpus                             |16              |
|pool                                |default         |
|virtual_hub                         |True            |
|ctlplanes                           |3               |
|ctlplane\_memory                    |32768           |
|ctlplanes\_numcpus                  |8               |
|virtual_workers                     |False           |
|workers                             |0               |
|worker\_memory                      |16384           |
|worker\_numcpus                     |8               |
|wait_for_workers                    |True            |
|wait_for_workers_number             |True            |
|wait_for_workers_exit_if_error      |False           |
|baremetal_ctlplanes                 |[]              |
|baremetal_workers                   |[]              |

### additional parameters

The following parameters are available when deploying the default plan

|Parameter                                    |Default Value                             |
|---------------------------------------------|------------------------------------------|
|bmc_password                                 |calvin                                    |
|bmc_user                                     |root                                      |
|cas                                          |[]                                        |
|create_network                               |False                                     |
|deploy_hub                                   |True                                      |
|disconnected                                 |False                                     |
|disconnected_operators                       |[]                                        |
|disconnected\_operators\_deploy\_after\_openshift|False                                 |
|disconnected_password                        |dummy                                     |
|disconnected_user                            |dummy                                     |
|dualstack                                    |False                                     |
|dualstack_cidr                               |None                                      |
|fips                                         |False                                     |
|go_version                                   |1.13.8                                    |
|http_proxy                                   |None                                      |
|image                                        |centos8stream                             |
|imagecontentsources                          |[]                                        |
|imageregistry                                |False                                     |
|installer_mac                                |None                                      |
|installer_wait                               |False                                     |
|keys                                         |[]                                        |
|launch_steps                                 |True                                      |
|model                                        |dell                                      |
|nfs                                          |True                                      |
|no_proxy                                     |None                                      |
|notify                                       |True                                      |
|notifyscript                                 |notify.sh                                 |
|ntp                                          |False                                     |
|ntp_server                                   |0.rhel.pool.ntp.org                       |
|numcpus                                      |16                                        |
|openshift_image                              |                                          |
|pullsecret                                   |openshift_pull.json                       |
|registry_image                               |quay.io/karmab/registry:amd64             |
|rhnregister                                  |True                                      |
|rhnwait                                      |30                                        |
|tag                                          |4.15                                      |
|version                                      |stable                                    |
|spoke_nodes                                    |[]                                        |
|spoke\_api\_ip                          |None                                      |
|spoke\_deploy                           |True                                      |
|spoke\_ingress\_ip                      |None                                      |
|spoke\_ctlplanes\_number                |1                                         |
|spoke\_name                             |mgmt-spoke1                               |
|spoke\_wait                             |False                                     |
|spoke\_wait_time                        |3600                                      |
|spoke\_workers_number                   |0                                         |
|spoke_virtual\_nodes                          |False                                     |
|spoke\_virtual\_nodes\_baremetal\_mac\_prefix  |aa:aa:aa:cc:cc                            |
|spoke\_virtual\_nodes\_disk\_size              |120                                       |
|spoke\_virtual_nodes\_memory                   |38912                                     |
|spoke\_virtual\_nodes\_number                  |1                                         |
|spoke\_virtual\_nodes\_numcpus                 |8                                         |

### Node parameters

when specifying *baremetal_ctlplanes* or *baremetal_workers* as an array, the specification can be created with something like this

```
- redfish_address: 192.168.123.45
  provisioning_mac: 98:03:9b:62:81:49
```

The following parameters can be used in this case:

- redfish_address. Redfish url
- boot_mode (optional). Should either be set to Legacy, UEFI or UEFISecureBoot
- bmc_user. If not specified, global bmc_password variable is used
- bmc_password.  If not specified, global bmc_password variable is used
- disk. Optional rootDeviceHint disk device
- ip, nic, gateway. Those attributes can be provided to set static networking using nmstate. Nic can be omitted. If gateway isn't provided, the static_gateway is used or gateway is guessed from baremetal_cidr

## Sample parameter files

The following sample parameter files are available for you to deploy:

- [lab.yml](lab.yml) This deploys 3 ctlplanes in a dedicated ipv4 network
- [lab_ipv6.yml](lab_ipv6.yml) This deploys 3 ctlplanes in a dedicated ipv6 network (hence in a disconnected manner) and a SNO spoke on top

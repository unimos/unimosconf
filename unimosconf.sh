#!/bin/sh
#
# Configuration script for use on routers running OpenWRT to connect to the
# Unimos network.
#
# Copyright 2013-2016 Luís Picciochi Oliveira <Pitxyoki@Gmail.com>
# Distribute under the terms of the GPLv3 license. See the LICENSE file.

#Base wireless config for test VM:
#
#touch /etc/config/wireless
#uci set wireless.wl0=wifi-device
#uci set wireless.@wifi-device[-1].type=broadcom
#uci set wireless.@wifi-device[-1].channel=11

#uci add wireless wifi-iface
#uci set wireless.@wifi-iface[-1].device=wl0
#uci set wireless.@wifi-iface[-1].network=lan
#uci set wireless.@wifi-iface[-1].mode=ap
#uci set wireless.@wifi-iface[-1].ssid=OpenWrt
#uci set wireless.@wifi-iface[-1].encryption=none

# Asks a question, giving yes or no possibilities for answer.
# As this is targeted at a Portuguese audience, 'yes' is 'sim'
#
# Parameters:
# $1: The question to ask
# Returns:
# 0: if the answer is yes/sim, or a shorthand
# 1: otherwise
bool_answer() {
  echo -n "$1 [s/N] "
  read VAR
  case "x${VAR}" in
    "xs"|"xsim"|"xS"|"xSIM"|"xy"|"xY"|"xyes"|"xYES")
      return 0;
      ;;
    *)
      return 1;
      ;;
  esac
}

# Echoes the list of ethernet interfaces attached to this device.
#
# Parameters:
# $1:    A simple string to match the interfaces against. E.g.: "eth" or "wlan"
# $2...: The list of ethernet interfaces NOT to include in the listing.
# Returns:
# The list of matching interfaces existing on the machine, separated by backslashes ('\').
get_ifaces() {
  RESULT=$(/sbin/ifconfig -a | grep Ethernet | cut -d" " -f 1|grep -E "($1)")
  if [ -n "$2" ]; then
    shift
    FILTER_EXPRESSION=$(echo "${RESULT}" | sed 's/ /|/g')
    RESULT=$(echo "${RESULT}" | grep -vxE "(${FILTER_EXPRESSION})")
  fi
  RESULT=$(echo "${RESULT}" | xargs | sed 's/ /\//g')
  echo ${RESULT}
}


# Echoes the 802.11g SSID name for the respective community
#
# Parameters:
# $1: The name of the local community.
# Returns:
# The conventioned name for the SSID on that community
get_mesh_ssid() {
  RESULT=""
  echo "x$1" | grep -qi "xourem" || echo "x$1" | grep -qi "xourém" && RESULT="aurenmesh."
  if [ -z "${RESULT}" ] ; then
    echo "x$1" | grep -qi "xervedosa" && RESULT="ervedosa."
  fi
  if [ -z "${RESULT}" ] ; then
    echo "x$1" | grep -qi "xnazare" || echo "x$1" | grep -qi "nazaré" && RESULT=""
  fi
  if [ -z "${RESULT}" ] ; then
    echo "x$1" | grep -qi "xlisboa" && RESULT="lisboa."
  fi

  echo ${RESULT}"unimos.net"
}

get_5ghz_ssid() {
  RESULT=""
  echo "x$1" | grep -qi "xourem" || echo "x$1" | grep -qi "xourém" && RESULT="AurenMesh-Castelos"
  if [ -z "${RESULT}" ] ; then
    echo "x$1" | grep -qi "xervedosa" && RESULT="Ervedosa - Unimos 5Bone"
  fi
  if [ -z "${RESULT}" ] ; then
    echo "x$1" | grep -qi "xnazare" || echo "x$1" | grep -qi "nazaré" && RESULT="Nazaré - Unimos 5Bone"
  fi
  if [ -z "${RESULT}" ] ; then
    echo "x$1" | grep -qi "xlisboa" && RESULT="Lisboa - Unimos 5Bone"
  fi

  echo ${RESULT}
}

echo "Script para configuração inicial de routers Unimos"
echo

echo "A fazer backup das configurações iniciais..."
cd /root/ && mkdir -p /root/backup && cp /etc/config/* /root/backup/ && chmod a-w /root/backup/*
if [ $? -eq 0 ]; then
  echo "Backup feito."
else
  echo "Problema ao criar backup. Configuração cancelada."
  return 1;
fi

echo -n "Comunidade para este router: "
read COMMUNITY

echo -n "Nome para este router: "
read ROUTER_NAME

echo "Coordenadas GPS do nó: "
echo -n "Latitude: "
read LATITUDE
echo -n "Longitude: "
read LONGITUDE

#TODO: validate ROUTER_NAME, LATITUDE & LONGITUDE


IFACE_NET=
bool_answer "Partilhar o acesso à Internet deste equipamento?"
if [ $? -eq 0 ]; then
  NET_IFACES=$(get_ifaces eth)
  echo "Interface que dá acesso à Internet: [${NET_IFACES}] "
  read IFACE_NET
  #TODO: validate IFACE_NET
  echo "Não esquecer: este interface deve ter um IP estático, a configurar no modem/gateway."
fi


echo "A detectar placas wireless..."
#TODO: This should detect *all* radios!
#uci set wireless.radio0.disabled=0
#uci set wireless.wifi0.disabled=0
#uci commit wireless
wifi


IFACES_11G=
IFACES_11A=
bool_answer "Este equipamento tem placa(s) wireless?"
if [ $? -eq 0 ] ; then

  WLAN_IFACES=$(get_ifaces 'wl|ath')
  while [ $? -eq 0 ] ; do

    if [ -z "${WLAN_IFACES}" ]; then
      echo "Nenhum interface possível detectado."
      break

    else
      echo "Interfaces possíveis: [${WLAN_IFACES}]"
      echo -n "Interface a configurar: "
      read CURR_IFACE

      #TODO: validate CURR_IFACE belongs to WLAN_IFACES
      #TODO: Validate CURR_STARTADDR / CURR_IP

      bool_answer "Interface 2GHz?"
      if [ $? -eq 0 ] ; then
        echo -n "Início da gama de IPs atribuída: (forma: 1.2.3.4) "
        read CURR_STARTADDR

        CURR_IP=$(echo ${CURR_STARTADDR} | awk -F"." '{print $1"."$2"."$3"."$4+1}')
        IFACES_11G="${IFACES_11G} ${CURR_IFACE} ${CURR_STARTADDR} ${CURR_IP}"
      else
        bool_answer "Interface 5GHz?"
        if [ $? -eq 0 ] ; then
          echo -n "IP para backbone deste nó: (forma: 1.2.3.4) "
          read CURR_IP

          IFACES_11A="${IFACES_11A} ${CURR_IFACE} ${CURR_IP}"
        fi
      fi

      #remove CURR_IFACE from WLAN_IFACES
      WLAN_IFACES=$(echo "${WLAN_IFACES}" | sed "s/${CURR_IFACE}//g" | sed 's/\/\//\//g' )
      bool_answer "Mais?"
    fi
  done
fi


#IFACES_11A=
#bool_answer "Este equipamento tem placa 802.11a?"
#if [ $? -eq 0 ] ; then
#
#  WLAN_IFACES=$(get_ifaces wl)
#  echo "Interfaces 802.11a possíveis: [${WLAN_IFACES}]"
#  while [ $? -eq 0 ] ; do
#    echo -n "Interface a configurar: "
#    read CURR_IFACE
#    #TODO: validate CURR_IFACE belongs to WLAN_IFACES
#    IFACES_11A="${IFACES_11G} ${CURR_IFACE} ${CURR_IFACE_IP}"
#    bool_answer "Mais?"
#  done
#fi

echo
echo 'A configuração vai iniciar agora.'
echo 'Enter para configurar. Ctrl+C para cancelar.'
read




# At this stage, all of these vars must be defined:
if [ -z "${IFACE_NET}" -a -z "${IFACES_11G}" -a -z "${IFACES_11A}" ]; then
  echo 'Nenhum interface para configurar.'
  exit 1;
fi


### Configuration done. Applying settings.
uci set system.@system[0].hostname=${ROUTER_NAME}
uci set system.@system[0].zonename='Europe/Lisbon'
uci set system.@system[0].timezone='WET0WEST,M3.5.0/1,M10.5.0'
uci delete system.ntp.server
uci add_list system.ntp.server=ntp02.oal.ul.pt
uci add_list system.ntp.server=ntp04.oal.ul.pt



opkg update
opkg install olsrd olsrd-mod-nameservice olsrd-mod-txtinfo olsrd-mod-arprefresh olsrd-mod-dyn-gw #$([ -n "${IFACE_NET}" ] && echo olsrd-mod-dyn-gw)

echo "A limpar definições de plugins OLSR..."
while [ $? -eq 0 ] ; do
  uci delete olsrd.@LoadPlugin[0] 2> /dev/null ;
done

echo "Definições de plugins OLSR limpas. A limpar definições de interfaces com OLSR..."
while [ $? -eq 0 ] ; do
  uci delete olsrd.@Interface[0] 2> /dev/null ;
done

while [ $? -eq 0 ] ; do
  uci delete olsrd.@Hna4[0] 2> /dev/null ;
done


echo "Definições de interfaces com OLSR limpas. A limpar definições globais do OLSR..."
while [ $? -eq 0 ] ; do
  uci delete olsrd.@olsrd[0] 2> /dev/null ;
done

echo "Definições globais do OLSR limpas. A configurar as novas definições..."

uci add olsrd olsrd
uci set olsrd.@olsrd[-1].DebugLevel=0
uci set olsrd.@olsrd[-1].IpVersion=4
uci set olsrd.@olsrd[-1].FIBMetric=flat
uci set olsrd.@olsrd[-1].AllowNoInt=yes
uci set olsrd.@olsrd[-1].Willingness=7
uci set olsrd.@olsrd[-1].LinkQualityLevel=2
uci set olsrd.@olsrd[-1].LinkQualityAlgorithm=etx_ff
uci set olsrd.@olsrd[-1].LinkQualityFishEye=1
uci set olsrd.@olsrd[-1].TcRedundancy=2
uci set olsrd.@olsrd[-1].MprCoverage=7

uci add olsrd LoadPlugin
uci set olsrd.@LoadPlugin[-1].library=olsrd_nameservice.so.0.3
uci set olsrd.@LoadPlugin[-1].hosts_file=/etc/hosts
uci set olsrd.@LoadPlugin[-1].resolv_file=/etc/resolv.conf.olsr
uci add_list olsrd.@LoadPlugin[-1].name=${ROUTER_NAME}
uci set olsrd.@LoadPlugin[-1].sighup_pid_file=/var/run/dnsmasq.pid
uci set olsrd.@LoadPlugin[-1].ignore=0
uci set olsrd.@LoadPlugin[-1].latlon_file=/var/run/latlon.js
uci set olsrd.@LoadPlugin[-1].lat=${LATITUDE}
uci set olsrd.@LoadPlugin[-1].lon=${LONGITUDE}

uci add olsrd LoadPlugin
uci set olsrd.@LoadPlugin[-1].library=olsrd_txtinfo.so.0.1
uci set olsrd.@LoadPlugin[-1].accept=127.0.0.1

uci add olsrd LoadPlugin
uci set olsrd.@LoadPlugin[-1]=LoadPlugin
uci set olsrd.@LoadPlugin[-1].library=olsrd_arprefresh.so.0.1
uci set olsrd.@LoadPlugin[-1].ignore=0

uci add olsrd IpcConnect
uci set olsrd.@IpcConnect[0].MaxConnections=0

#if [ ! -z $IFACE_NET ]; then
  #uci set network.lan=interface
  #uci set network.lan.ifname=${IFACE_NET}
  #uci set network.lan.proto=dhcp
  #uci set network.lan.ipaddr=${NET_IPADDR}
  #uci set network.lan.netmask=255.255.255.0

  uci add olsrd LoadPlugin
  uci set olsrd.@LoadPlugin[-1].library=olsrd_dyn_gw.so.0.5
  uci set olsrd.@LoadPlugin[-1].Ping=141.1.1.1
  uci set olsrd.@LoadPlugin[-1].Interval=60
#fi



echo "A Configurar servidor DNS..."
uci delete dhcp.@dnsmasq[0]
uci add dhcp dnsmasq
uci set dhcp.@dnsmasq[0].filterwin2k=1
uci set dhcp.@dnsmasq[0].noresolv=1
uci set dhcp.@dnsmasq[0].nonegcache=1
uci set dhcp.@dnsmasq[0].domainneeded=1
uci set dhcp.@dnsmasq[0].domain=unimos.net
uci set dhcp.@dnsmasq[0].expandhosts=1
uci set dhcp.@dnsmasq[0].leasefile='/var/dhcp.leases'
uci add_list dhcp.@dnsmasq[0].server='8.8.8.8'
uci add_list dhcp.@dnsmasq[0].server='8.8.4.4'


NUMBER_11G=$(echo ${IFACES_11G} | awk '{print NF}')

while [ ${NUMBER_11G} -gt 0 ]; do
  CURR_IFACE=$(echo ${IFACES_11G} | awk '{print $1}')
  CURR_STARTADDR=$(echo ${IFACES_11G} | awk '{print $2}')
  CURR_IP=$(echo ${IFACES_11G} | awk '{print $3}');

  echo
  echo "A configurar interface para mesh 2GHz: ${CURR_IFACE}"
  echo "IP: ${CURR_IP}"
  echo "Início da sub-rede: ${CURR_STARTADDR}"
  echo "Netmask: 255.0.0.0"

  uci set network.mesh=interface
  uci set network.mesh.ifname=${CURR_IFACE}
  uci set network.mesh.proto=static
  uci set network.mesh.netmask=255.0.0.0
  uci set network.mesh.ipaddr=${CURR_IP}

  uci set wireless.@wifi-device[0].disabled=0
  uci set wireless.@wifi-iface[0].network=mesh
  uci set wireless.@wifi-iface[0].mode=adhoc
  uci set wireless.@wifi-iface[0].ssid=$(get_mesh_ssid ${COMMUNITY})
  uci set wireless.@wifi-iface[0].bssid="02:CA:FF:EE:BA:BE"
  uci set wireless.@wifi-iface[0].encryption=none

  uci add olsrd Hna4
  uci set olsrd.@Hna4[-1].netaddr=${CURR_STARTADDR}
  uci set olsrd.@Hna4[-1].netmask=255.255.255.224

  uci add olsrd Interface
  uci set olsrd.@Interface[-1].ignore=0
  uci set olsrd.@Interface[-1].interface=mesh
  uci set olsrd.@Interface[-1].HelloInterval=3.0
  uci set olsrd.@Interface[-1].HelloValidityTime=300.0
  uci set olsrd.@Interface[-1].TcInterval=2.0
  uci set olsrd.@Interface[-1].TcValidityTime=500.0
  uci set olsrd.@Interface[-1].MidInterval=25.0
  uci set olsrd.@Interface[-1].MidValidityTime=500.0
  uci set olsrd.@Interface[-1].HnaInterval=25.0
  uci set olsrd.@Interface[-1].HnaValidityTime=500.0

  CURR_DHCPSTART=$(echo ${CURR_STARTADDR} | awk -F"." '{print $4+2}')
  uci set dhcp.mesh=dhcp
  uci set dhcp.@dhcp[-1].interface=mesh
  uci set dhcp.@dhcp[-1].start=${CURR_DHCPSTART}
  uci set dhcp.@dhcp[-1].limit=28
  uci set dhcp.@dhcp[-1].netmask=255.255.255.224
  uci set dhcp.@dhcp[-1].leasetime=6h
  uci set dhcp.@dhcp[-1].force=1

  ADD_TO_IPTABLES="${ADD_TO_IPTABLES}
        # Trafego Unimos->LAN, nao relacionado com pedidos iniciados antes, e' perdido
        iptables -A FORWARD -i $CURR_IFACE -d 192.168.0.0/16 -j DROP"

  IFACES_11G=$(echo ${IFACES_11G} | echo $(read one two three rest && echo ${rest}))
  NUMBER_11G=$(echo ${IFACES_11G} | awk '{print NF}')
done



NUMBER_11A=$(echo ${IFACES_11A} | awk '{print NF}')

while [ ${NUMBER_11A} -gt 0 ]; do
  CURR_IFACE=$(echo ${IFACES_11A} | awk '{print $1}')
  CURR_IP=$(echo ${IFACES_11A} | awk '{print $2}' )

  echo
  echo "A configurar interface para backbone 5GHz: ${CURR_IFACE}"
  echo "IP: ${CURR_IP}"
  echo "Netmask: 255.255.255.0"

  uci set network.backbone=interface
  uci set network.backbone.ifname=${CURR_IFACE}
  uci set network.backbone.proto=static
  uci set network.backbone.netmask=255.255.255.0
  uci set network.backbone.ipaddr=${CURR_IP}

  uci set wireless.@wifi-iface[0].network=backbone
  uci set wireless.@wifi-iface[0].mode=adhoc
  uci set wireless.@wifi-iface[0].ssid=$(get_5ghz_ssid)
  uci set wireless.@wifi-iface[0].bssid="02:C0:FF:EE:BA:BE"
  uci set wireless.@wifi-iface[0].encryption=none

  uci add olsrd Interface
  uci set olsrd.@Interface[-1].ignore=0
  uci set olsrd.@Interface[-1].interface=backbone
  uci set olsrd.@Interface[-1].HelloInterval=3.0
  uci set olsrd.@Interface[-1].HelloValidityTime=300.0
  uci set olsrd.@Interface[-1].TcInterval=2.0
  uci set olsrd.@Interface[-1].TcValidityTime=500.0
  uci set olsrd.@Interface[-1].MidInterval=25.0
  uci set olsrd.@Interface[-1].MidValidityTime=500.0
  uci set olsrd.@Interface[-1].HnaInterval=25.0
  uci set olsrd.@Interface[-1].HnaValidityTime=500.0


  ADD_TO_IPTABLES="${ADD_TO_IPTABLES}
        # Trafego Unimos->LAN, nao relacionado com pedidos iniciados antes, e' perdido
        iptables -A FORWARD -i $CURR_IFACE -d 192.168.0.0/16 -j DROP"

  IFACES_11A=$(echo ${IFACES_11A} | echo $(read one two rest && echo ${rest}))
  NUMBER_11A=$(echo ${IFACES_11A} | awk '{print NF}')
done


if [ -n "${IFACE_NET}" ] ; then
  ADD_TO_IPTABLES="${ADD_TO_IPTABLES}
      # Tra'fego Unimos->Internet e' mascarado
      iptables -t nat -A POSTROUTING  -s 10.0.0.0/8 -o ${IFACE_NET} -j MASQUERADE"
fi




echo "A finalizar configurações..."
echo 'Enter para finalizar. Ctrl+C para cancelar. (Última hipótese!)'
read

uci commit

if [ $? -eq 0 ]; then
  echo "Tudo OK! Definir password para root: "
  passwd

  /etc/init.d/firewall disable
  cat <<EOF > /etc/init.d/${COMMUNITY}mesh
#!/bin/sh /etc/rc.common

START=45

start() {
        # So aceitar tra'fego para a LAN, se iniciado a partir da mesma
        iptables -A FORWARD -m state -d 192.168.0.0/16 --state RELATED,ESTABLISHED -j ACCEPT

        # Tra'fego LAN->Unimos e' mascarado
        iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -j MASQUERADE

        ${ADD_TO_IPTABLES}
}

stop() {
        iptables -F
        iptables -t nat -F
}
EOF
  chmod +x /etc/init.d/${COMMUNITY}mesh
  /etc/init.d/${COMMUNITY}mesh enable
  /etc/init.d/olsrd enable


  if [ ! -z ${IFACE_NET} ]; then
      echo
      echo "ATENÇÃO!!!!"
      echo "Este router partilha um acesso à Internet:"
      echo "Não esquecer de configurar acesso no-ip ou dyndns para acesso remoto."
  fi


else
  echo "Algo correu mal. :-( Nenhuma alteração gravada."
fi


echo "Enter para reiniciar o router. (Ctrl+C para continuar sem reiniciar)"
read
reboot; exit;


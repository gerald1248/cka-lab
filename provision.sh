#!/bin/sh

# set up hosts file
cat <<-EOF >>/etc/hosts
192.168.56.100 ckalb
192.168.56.101 ckamaster1 ckamaster
192.168.56.102 ckamaster2
192.168.56.103 ckamaster3
192.168.56.104 ckaworker1
192.168.56.105 ckaworker2
EOF

# allow root ssh logins
printf '\nPermitRootLogin yes\n' >> /etc/ssh/sshd_config
printf '\nStrictHostKeyChecking no\n' >>/etc/ssh/ssh_config
systemctl restart sshd

# Make a student sudo user with password welcome1
useradd student -m -p '$6$UhZjFYH1$9RiEbku8QFfIiKq0mf5spCHABaAK218nbH/c3ISzc63v5VRmM/2aUSRpsq3IAJ025.yXbOSJPCpr.VsgG.g3o.' -s /bin/bash
mkdir -p /home/student/.ssh
cp /vagrant/id_rsa /home/student/.ssh/
cp /vagrant/id_rsa.pub /home/student/.ssh/authorized_keys
chmod 0644 /home/student/.ssh/authorized_keys
printf 'student ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/student
chmod 440 /etc/sudoers.d/student

# swap not allowed
swapoff -a

# allow ssh between nodes
cp /vagrant/id_rsa /root/.ssh
cp /vagrant/id_rsa.pub /root/.ssh/authorized_keys
chmod 0600 /root/.ssh/*

# fix locale
locale-gen "en_US.UTF-8"
update-locale LC_ALL="en_US.UTF-8"

# import key and add k8s apt repo
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# copy initial kubadm and calico config yaml files
cp /vagrant/kubernetes/kubeadm-config.yaml /home/student/kubeadm-config.yaml
cp /vagrant/kubernetes/calico.yaml /vagrant/kubernetes/rbac-kdd.yaml /home/student/

# update, upgrade and instal nfs client tools
apt-get update && apt-get upgrade -y && apt-get install -y nfs-common

# differentiate between host types: ckamaster, ckaworker, ckalb
case $(hostname) in
ckamaster*)
cat >/home/student/install-master.sh <<EOF
# install components
sudo apt install -y docker.io kubeadm=1.15.1-00 kubectl=1.15.1-00 kubelet=1.15.1-00
sudo apt-mark hold docker.io kubeadm kubectl kubelet

# init
sudo kubeadm init --config=kubeadm-config.yaml --upload-certs | tee kubeadm-init.out
mkdir -p /home/student/.kube

# set up kubeconfig
sudo cp -i /etc/kubernetes/admin.conf /home/student/.kube/config
sudo chown student /home/student/.kube/config
EOF

cat >/home/student/apply-flannel.sh <<EOF
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
EOF

cat >/home/student/apply-calico.sh <<EOF
kubectl apply -f rbac-kdd.yaml calico.yaml
EOF
  ;;
ckaworker*)
cat >/home/student/install-worker.sh <<EOF
sudo apt install -y docker.io kubeadm=1.15.1-00 kubectl=1.15.1-00 kubelet=1.15.1-00
sudo apt-mark hold docker.io kubeadm kubectl kubelet
EOF
  ;;
*)
  ;;
esac


#!/bin/bash -ex
### Build a docker image for ubuntu i386.

### settings
arch=i386
suite=${1:-bionic}
chroot_dir="/var/chroot/$suite"
apt_mirror='http://old-releases.ubuntu.com/ubuntu'
docker_image="32bit/ubuntu:$suite"

### make sure that the required tools are installed
#packages="debootstrap schroot apparmor"
#which docker || packages="$packages docker.io"
#apt-get install -y $packages

### install a minbase system with debootstrap
export DEBIAN_FRONTEND=noninteractive
debootstrap --variant=minbase --arch=$arch $suite $chroot_dir $apt_mirror

echo "Sources list"
### update the list of package sources
cat <<EOF > $chroot_dir/etc/apt/sources.list
deb $apt_mirror $suite main restricted universe multiverse
deb $apt_mirror $suite-updates main restricted universe multiverse
deb $apt_mirror $suite-backports main restricted universe multiverse
deb http://old-releases.ubuntu.com/ubuntu $suite-security main restricted universe multiverse
EOF

echo "chroot"
### install ubuntu-minimal
cp /etc/resolv.conf $chroot_dir/etc/resolv.conf
mount -o bind /proc $chroot_dir/proc
chroot $chroot_dir apt-get update
chroot $chroot_dir apt-get --force-yes -y upgrade
# Old Ubuntu releases fix (for upstart that doesn't work properly)
chroot $chroot_dir dpkg-divert --local --rename --add /sbin/initctl
chroot $chroot_dir ln -s /bin/true /sbin/initctl
chroot $chroot_dir apt-get --force-yes -y install ubuntu-minimal

### cleanup
chroot $chroot_dir apt-get autoclean
chroot $chroot_dir apt-get clean
chroot $chroot_dir apt-get autoremove
rm $chroot_dir/etc/resolv.conf

echo "Sometest"
### kill any processes that are running on chroot
chroot_pids=$(for p in /proc/*/root; do ls -l $p; done | grep $chroot_dir | cut -d'/' -f3)
test -z "$chroot_pids" || (kill -9 $chroot_pids; sleep 2)

### unmount /proc
umount $chroot_dir/proc

### create a tar archive from the chroot directory
tar cfz ubuntu.tgz -C $chroot_dir .

echo "Importing?"
### import this tar archive into a docker image:
cat ubuntu.tgz | docker.io import - $docker_image --message "Build with https://github.com/docker-32bit/ubuntu"

echo "pushing docker image"
# ### push image to Docker Hub
#docker push $docker_image

### cleanup
rm ubuntu.tgz
rm -rf $chroot_dir

FEDORA_RELEASE_RPM_NAME = fedora-release-19-5.noarch.rpm
ROOTFS = build/root

all: $(ROOTFS)

clean:
	sudo rm -fr build

build/$(FEDORA_RELEASE_RPM_NAME):
	-mkdir $(@D)
	yumdownloader --destdir=build fedora-release
	test -e $@

$(ROOTFS): build/$(FEDORA_RELEASE_RPM_NAME)
	echo "Testing sudo works - if this fails add the following line to /etc/sudoers:"
	echo '<username>	ALL=NOPASSWD:	ALL'
	echo "and consider commenting out RequireTTY"
	sudo -n true
	echo "Cleaning"
	-sudo rm -fr $(ROOTFS) $(ROOTFS).tmp
	mkdir -p $(ROOTFS).tmp
	mkdir -p $(ROOTFS).tmp/var/lib/rpm
	echo "Unpacking release packages"
	sudo rpm --root $(abspath $(ROOTFS)).tmp --initdb
	sudo rpm --root $(abspath $(ROOTFS)).tmp -ivh $<
	echo "Blocking default fedora repositories"
	sudo sed -i 's/enabled=1/enabled=0/' $(ROOTFS).tmp/etc/yum.repos.d/fedora*repo*
	echo "Adding strato frozen repositories"
	sudo cp /etc/yum.repos.d/frozenstrato.repo $(ROOTFS).tmp/etc/yum.repos.d
	echo "Installing minimal install"
	sudo yum --nogpgcheck --installroot=$(abspath $(ROOTFS)).tmp groupinstall "minimal install" --assumeyes
	echo
	echo "writing configuration 1: re-disabling default fedora repositories"
	sudo sed -i 's/enabled=1/enabled=0/' $(ROOTFS).tmp/etc/yum.repos.d/fedora*repo*
	echo "writing configuration 2: /etc/fstab"
	sudo cp fstab $(ROOTFS).tmp/etc/
	echo "writing configuration 3: disabling selinux"
	sudo cp selinux.config $(ROOTFS).tmp/etc/selinux/config
	echo "writing configuration 4: /etc/resov.conf"
	sudo cp /etc/resolv.conf $(ROOTFS).tmp/etc/
	echo "writing configuration 5: ethernet configuration"
	sudo cp ifcfg-eth0 $(ROOTFS).tmp/etc/sysconfig/network-scripts/ifcfg-eth0
	echo
	echo "creating missing directories"
	sudo cp -a /dev $(ROOTFS).tmp/
	echo
	mv $(ROOTFS).tmp $(ROOTFS)

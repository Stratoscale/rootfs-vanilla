FEDORA_RELEASE_RPM_NAME = fedora-release-19-5.noarch.rpm
ROOTFS = build/root

all: $(ROOTFS)

submit:
	sudo -E solvent submitproduct rootfs $(ROOTFS)

approve:
	sudo -E solvent approve --product=rootfs

clean:
	sudo rm -fr build

build/$(FEDORA_RELEASE_RPM_NAME):
	-mkdir $(@D)
	yumdownloader --config=frozenfedora.yum.conf --destdir=build fedora-release
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
	sudo rm -fr $(ROOTFS).tmp/etc/yum.repos.d/*repo*
	echo "Adding strato frozen repositories"
	sed 's/.*reposdir.*//' frozenfedora.yum.conf | sudo sh -c "cat > $(ROOTFS).tmp/etc/yum.conf"
	echo "Installing minimal install"
	sudo yum --nogpgcheck --installroot=$(abspath $(ROOTFS)).tmp groupinstall "minimal install" --assumeyes
	echo "Updating"
	sudo chroot $(ROOTFS).tmp yum upgrade --assumeyes
	echo "Install kernel and boot loader"
	sudo chroot $(ROOTFS).tmp yum install kernel grub2 fedora-release kexec-tools lvm2 --assumeyes
	echo
	echo "writing configuration 1: disabling selinux"
	sudo cp selinux.config $(ROOTFS).tmp/etc/selinux/config
	echo "writing configuration 2: /etc/resov.conf"
	sudo cp /etc/resolv.conf $(ROOTFS).tmp/etc/
	echo "writing configuration 3: ethernet configuration"
	sudo cp ifcfg-eth0 $(ROOTFS).tmp/etc/sysconfig/network-scripts/ifcfg-eth0
	echo "writing configuration 4: boot-loader"
	sudo cp etc_default_grub $(ROOTFS).tmp/etc/default/grub
	sudo ./chroot.sh $(ROOTFS).tmp grub2-mkconfig -o /boot/grub2/grub.cfg || true
	test -e $(ROOTFS).tmp/boot/grub2/grub.cfg
	sudo sh -c "echo 'add_dracutmodules+=\"lvm\"' >> $(ROOTFS).tmp/etc/dracut.conf"
	sudo ./chroot.sh $(ROOTFS).tmp dracut --kver=`ls $(ROOTFS).tmp/lib/modules` --force
	sudo grep console.ttyS0 $(ROOTFS).tmp/boot/grub2/grub.cfg
	sudo rm -fr $(ROOTFS).tmp/tmp/* $(ROOTFS).tmp/var/tmp/*
	echo
	mv $(ROOTFS).tmp $(ROOTFS)

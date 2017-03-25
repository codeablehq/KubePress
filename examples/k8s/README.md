## Building a basic WordPress-ready Kubernetes stack

(Creating the stack itself is out of scope of this project, so before you begin, make sure you have Kubernetes running, and `kubectl cluster-info` returns proper information)

Since Databases are inherently stateful, it's not recommended you put them into container but rather build a dedicated instance (or multiple, if you want replication and high-availability) or defer database administration to one of the numerous hosted solutions (Google Cloud SQL, for example).

Once your database server is up and running, create a database and a user that our WordPress install will use to access it:
```
> CREATE DATABASE [your database name] CHARACTER SET utf8 COLLATE utf8_general_ci;
> CREATE USER '[your user]'@'%' IDENTIFIED BY '[your password]';
> GRANT ALL PRIVILEGES ON [your database name].* TO '[your user]'@'%';
> FLUSH PRIVILEGES;
```

With your DB password ready, create base64 secrets by taking each secret and running the following command with it (if on unix system):
`echo 'the_secret' | base64`

Then, with all your secrets populated:
`$ kubectl create -f secrets.yml`

Now comes the tricky part. In order for WordPress to run on many separate nodes, we need to share `wp-content` among all of them, and _it needs to be writeable_ from any given pod.

To achieve that, we need a network-accessible disk, and one of the best options is [GlusterFS](https://www.gluster.org/).

Setting up a basic, two instance GlusterFS cluster requires the following actions (steps marked with _optional_ mean you can attach an external disk to the instance, rather than using it's own, which most of Cloud providers support):

1. create two instances/nodes and run the following commands on both:
2. (optional) create and attach a disk (actions depend on provider)
3. (optional) install the necessary formatting tools: `$ sudo apt-get install -y xfsprogs`
4. (optional) format the disk: `$ sudo mkfs.xfs -i size=512 /dev/disk/by-id/[DISK_NAME]` (path varies depending on cloud provider)
5. create a directory: `$ sudo mkdir -p /mnt/brick1`
6. (optional) set permissions: `$ sudo chmod a+w /mnt/brick1`
7. (optional) save mounts: `$ echo UUID=sudo blkid -s UUID -o value /dev/disk/by-id/[DISK_NAME] /mnt/brick1 xfs defaults 1 2 | sudo tee -a /etc/fstab`
8. (optional) mount it: `$ sudo mount /mnt/brick1`
9. create `wp-content`: `$ sudo mkdir -p /mnt/brick1/wp-content`
10. [Install GlusterFS](https://gluster.readthedocs.io/en/latest/Install-Guide/Install/)
11. Assuming the instance IPs are `10.0.0.1` and `10.0.0.2`, probe them between one another; Run `$ gluster peer probe 10.0.0.1` on the instance with IP `10.0.0.2` and vice versa.
12. On *one* instance, create a volume: `$ gluster volume create wp-content replica 2 10.0.0.1:/mnt/brick1/wp-content 10.0.0.2:/mnt/brick1/wp-content` (since they are probed, it will take effect on both instances)
13. On *one* instance, start the volume `$ gluster volume start wp-content`
14. The `wp-content` directory is now set and can be mounted onto pods with write permissions, but it's currently empty, so you need to populate it with either the default `wp-content` files and directories that come with WordPress (for new installations) or move your existing WordPress `wp-content` into it. *Do not, however, copy files directly into `/mnt/brick1/wp-content`!* Doing so will bypass GlusterFS and make your two instances out of sync! Instead, mount the GlusterFS-mounted disk (mountception!): `mount -t glusterfs localhost:/wp-content /mnt/wp-content`. You can now freely modify everything in `/mnt/wp-content` and GlusterFS will automatically do it's job: sync changes.

With GlusterFS up and running, create Kubernetes endpoints:
`$ kubectl create -f glusterfs.yml`

And finally deploy this WordPress image:
`$ kubectl create -f deployment.yml`

Before you can access it from the internet, there's one last step to take, you need to expose it with a service:
`$ kubectl create -f service.yml`

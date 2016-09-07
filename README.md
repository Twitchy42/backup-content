# backup-content
CQ5 content backup script

This is a ruby script for backing up content from AEM CQ5 servers. I've scrubbed out some values to make this version as generic as possible

It references a ConnectionInfo class that I have not included here. Suffice to say that it uses the AWS SDK for Ruby to return server information.

Call this script with server names as arguments. If it is a Cloud Formation stack name it searches by that, otherwise hostnames or dns names.
It will make a series of curl commands to create the content package on CQ5, then upload it to artifactory.

This is used for timed or on-demand content backups and as part of syncing content between environments.

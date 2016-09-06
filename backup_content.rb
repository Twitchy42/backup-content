require 'time'
require 'logger'
require 'json'
require_relative 'connection_info'

$logger.level = Logger::INFO
args = ARGV.map { |a| a }

class ContentBackup

  def self.backup_content server
	source = nil
	all_servers = {}

	if server.start_with?('cf_stack_')
  	stack_name = server.downcase.gsub('-','_').gsub('cf_stack_','')
  	source = ConnectionInfo.query_servers ({ "cf_stack" => stack_name, "type" => /publish|author/ })
	else
  	server_regexp = Regexp.new(server, Regexp::IGNORECASE)
  	source = ConnectionInfo.query_servers ({ "hostname" => server_regexp }) || ConnectionInfo.query_servers({ "dns_name" => server_regexp })
	end

	source.each do |s|
  	$logger.info "Source: #{s}"
    	pass = s.instance_variable_get(:@password)
    	self.make_package(s, pass)
	end

  rescue => ex
	$logger.error "Something went horribly wrong: #{ex}"
  end


  def self.make_package s, pass
	t = Time.now
	ftime = t.strftime("%Y%m%d%H%M%S")
	packageName = "#{s.hostname}_content_#{ftime}"

	$logger.info "name the package"
	`curl -u admin:#{pass} -X POST http://#{s.ip_address}:#{s.port}/crx/packmgr/service/.json/etc/packages/my_packages?cmd=create -d packageName=#{packageName} -d groupName=my_packages`
	$logger.info "give it filters"
	`curl -u admin:#{pass} -F "path=/etc/packages/my_packages/#{packageName}.zip" -F "packageName=#{packageName}" -F "groupName=my_packages" -F 'filter=[{"root":"/content/","rules":[]}]' http://#{s.ip_address}:#{s.port}/crx/packmgr/update.jsp`
	$logger.info "build it.."
	`curl -u admin:#{pass} -X POST http://#{s.ip_address}:#{s.port}/crx/packmgr/service/.json/etc/packages/my_packages/#{packageName}.zip?cmd=build`
	$logger.info "now download it"
	`curl -o #{ENV['WORKSPACE']}/#{packageName}.zip -u admin:#{pass} http://#{s.ip_address}:#{s.port}/etc/packages/my_packages/#{packageName}.zip`

	#upload to artifactory
	artifactory_url = "http://some.address.com:8081/artifactory/simple/content/#{s.hostname}/#{packageName}.zip"
	`curl -v --user admin:password --data-binary @#{ENV['WORKSPACE']}/#{packageName}.zip -X PUT #{artifactory_url}`

	#remove the backups from CRX
	`curl -u admin:#{pass} -X POST http://#{s.ip_address}:#{s.port}/crx/packmgr/service/.json/etc/packages/my_packages/#{packageName}.zip?cmd=delete`

  end

end

args.each do |a|
  ContentBackup.backup_content(a)
end

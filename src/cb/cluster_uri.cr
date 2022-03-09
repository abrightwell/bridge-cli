require "./action"

class CB::ClusterURI < CB::ClusterAction
  def run
    uri = client.get_cluster_default_role(cluster_id).uri
    output = uri.to_s
    pw = uri.password
    output = output.gsub(pw, pw.colorize.black.on_black.to_s) if pw
    puts output
  end
end

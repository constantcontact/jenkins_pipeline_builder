module JenkinsPipelineBuilder
  class PullReqGen
    def self.pull_request_gen(job, xml)
      #Count the jobs
      if job[:jobs].count > 1
        # Inject Header Code
        dsl = "import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
// Setup for ignoring self-signed certificate errors
def nullTrustManager = [
checkClientTrusted: { chain, authType -> },
checkServerTrusted: { chain, authType -> },
getAcceptedIssuers: { null }
]
def nullHostnameVerifier = [
verify: { hostname, session -> true }
]
SSLContext sc = SSLContext.getInstance(\"SSL\")
sc.init(null, [nullTrustManager as X509TrustManager] as TrustManager[], null)
HttpsURLConnection.setDefaultSSLSocketFactory(sc.getSocketFactory())
HttpsURLConnection.setDefaultHostnameVerifier(nullHostnameVerifier as HostnameVerifier)
// Get existing jobs so we know which jobs are new and can be queued
def jenkins_api = new URL(\"https://p2-sahud101.ad.prodcc.net/view/All/api/json?pretty=true\")
def jenkins_jobs = new groovy.json.JsonSlurper().parse(jenkins_api.newReader())
def pullUrl = new URL(\"https://github.roving.com/api/v3/repos/#{job[:git_org]}/#{job[:git_repo]}/pulls\")
println \"Using: pullUrl = ${pullUrl}\"
def pulls = new groovy.json.JsonSlurper().parse(pullUrl.newReader())
println \"Starting to process #{job[:git_repo]}\"
// Now we create the jobs for each pull request
pulls.each {
def pullRequestNumber = it.number
def pullRequestTitle = it.title
def feature = it.head.ref
def gitBranch = \"origin/pr/${pullRequestNumber}/head\"
def headSha = it.head.sha
";
    # Inject Jobs
    job[:jobs].each do |j|
      dsl << "
job {
using(\"#{j}\")
name \"#{j}-pr${pullRequestNumber}\"
configure { project ->
  (project / 'scm' / 'branches' / 'hudson.plugins.git.BranchSpec' / 'name').setValue(gitBranch)
  (project / 'scm' / 'userRemoteConfigs' / 'hudson.plugins.git.UserRemoteConfig' / 'name') << {}
  (project / 'scm' / 'userRemoteConfigs' / 'hudson.plugins.git.UserRemoteConfig' / 'refspec').setValue('+refs/pull/*:refs/remotes/origin/pr/*')
  def pubNode = project / 'publishers'
  def gitNode = pubNode / 'hudson.plugins.git.GitPublisher'
  pubNode.remove(gitNode)
  (project / 'publishers' / 'jenkins.plugins.github__pull__request__notifier.GithubPullRequestNotifier' / 'pullRequestNumber' ).setValue(\"${pullRequestNumber}\")
  (project / 'publishers' / 'jenkins.plugins.github__pull__request__notifier.GithubPullRequestNotifier' / 'groupRepo' ).setValue(\"#{job[:git_org]}/#{job[:git_repo]}\")
  }
}
"
        end
        # Inject Footer Code
        dsl << '
}'
        job[:job_dsl] = dsl
        job
      end
    end
  end
end
class IssueTrackers::RedmineTracker < IssueTracker
  Label = "redmine"
  Fields = [
    [:account, {
      :label       => "Redmine URL",
      :placeholder => "e.g. http://www.redmine.org/"
    }],
    [:api_token, {
      :placeholder => "API Token for your account"
    }],
    [:project_id, {
      :label       => "Ticket Project",
      :placeholder => "Redmine Project where tickets will be created"
    }],
    [:alt_project_id, {
      :optional    => true,
      :label       => "App Project",
      :placeholder => "Where app's files & revisions can be viewed. (Leave blank to use the above project by default)"
    }]
  ]

  def check_params
    if Fields.detect {|f| self[f[0]].blank? && !f[1][:optional]}
      errors.add :base, 'You must specify your Redmine URL, API token and Project ID'
    end
  end

  def create_issue(problem, reported_by = nil)
    token = api_token
    acc = account
    RedmineClient::Base.configure do
      self.token = token
      self.site = acc
      self.format = :xml
    end
    issue = RedmineClient::Issue.new(:project_id => project_id)
    issue.subject = issue_title problem
    issue.description = body_template.result(binding)
    issue.save!
    problem.update_attributes(
      :issue_link => issue_link(issue.id),
      :issue_type => Label
    )
  end

  def link_issue(problem, issue_id)
    token = api_token
    acc = account
    RedmineClient::Base.configure do
      self.token = token
      self.site = acc
      self.format = :xml
    end
    issue = RedmineClient::Issue.find(issue_id)
    issue.notes = body_template.result(binding)
    issue.save!
    problem.update_attributes(
      :issue_link => issue_link(issue_id),
      :issue_type => Label
    )
  end

  def url_to_file(file_path, line_number = nil)
    # alt_project_id let's users specify a different project for tickets / app files.
    project = self.alt_project_id.present? ? self.alt_project_id : self.project_id
    url = "#{self.account}/projects/#{project}/repository/annotate/#{file_path.sub(/^\//,'')}"
    line_number ? url << "#L#{line_number}" : url
  end

  def body_template
    @@body_template ||= ERB.new(File.read(Rails.root + "app/views/issue_trackers/textile_body.txt.erb"))
  end

  def url
    acc_url = account.start_with?('http') ? account : "http://#{account}"
    acc_url = "#{acc_url}/" unless acc_url.ends_with?('/')
    URI.parse("#{acc_url}projects/#{project_id}").to_s
  rescue URI::InvalidURIError
  end

  protected
  def issue_link(issue_id)
    "#{RedmineClient::Issue.site.to_s.sub(/#{RedmineClient::Issue.site.path}$/, '')}#{RedmineClient::Issue.element_path(issue_id, :project_id => project_id)}".sub(/\.xml\?project_id=#{project_id}$/, "\?project_id=#{project_id}")
  end
end


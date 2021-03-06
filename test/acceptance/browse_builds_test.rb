require "helper/acceptance"

class BrowseBuildsTest < Test::Unit::AcceptanceTestCase
  story <<-EOS
    As a user,
    I want to browse the builds of a project in Integrity
    So I can see the history of a project
  EOS

  scenario "Browsing to a project with no builds" do
    Project.gen(:blank, :name => "Integrity")

    visit "/integrity"

    assert_have_no_tag("#last_build")
    assert_have_no_tag("#previous_builds")
    assert_contain("No builds for this project, buddy")

    click_link "GitHub"
    assert last_request.url.include?("http://github.com")
  end

  scenario "Browsing to a project with all kind of builds" do
    builds = 
      2.of { Build.gen(:failed) }     +
      2.of { Build.gen(:pending) }    +
      3.of { Build.gen(:successful) }
    Project.gen(:integrity, :builds => builds, :last_build => builds.last)

    visit "/integrity"

    assert_have_tag("#last_build[@class='success']")

    within("ul#previous_builds") do
      assert_have_tag("li.pending", :count => 2)
      assert_have_tag("li.failed",  :count => 2)
      assert_have_tag("li.success", :count => 3)
    end

    click_link Build.first.sha1_short
    click_link "on GitHub"
    assert last_request.url.include?("http://github.com")

    visit "/integrity"
    click_link "raw"
    assert_equal Project.first(:name => "Integrity").last_build.output,
      last_response.body
  end

  scenario "Looking for details on the last build" do
    build = Build.gen(:successful, :output => "This is the build output")
    build.commit.raise_on_save_failure = true
    build.commit.update(
      :identifier => "7fee3f0014b529e2b76d591a8085d76eab0ff923",
      :author  => "Nicolas Sanguinetti <contacto@nicolassanguinetti.info>",
      :message => "No more pending tests :)",
      :committed_at => Time.mktime(2008, 12, 15, 18)
    )
    p = Project.gen(:integrity, :builds => [build], :last_build => build)

    visit "/integrity"

    assert_have_tag("h1",           :content => "Built 7fee3f0 successfully")
    assert_have_tag("blockquote p", :content => "No more pending tests")
    assert_have_tag("span.who",     :content => "by: Nicolas Sanguinetti")
    assert_have_tag("span.when",    :content => "Dec 15th")
    assert_have_tag("pre.output",   :content => "This is the build output")
  end

  scenario "Browsing to an individual build page" do
    builds = [
      Build.gen(:successful, :commit => Commit.gen(:identifier => "87e673a")),
      Build.gen(:pending, :commit => Commit.gen(:identifier => "7fee3f0")),
      Build.gen(:pending)
    ]
    Project.gen(:integrity, :builds => builds, :last_build => builds.last)

    visit "/integrity"
    click_link(/Build 87e673a/)

    assert_have_tag("h1", :content => "Built 87e673a successfully")
    assert_have_tag("h1", :content => "in 2m")
    assert_have_tag("h2", :content => "Build Output")
    assert_have_tag("button", :content => "Rebuild")

    visit "/integrity"
    click_link(/Build 7fee3f0/)

    assert_have_tag("h1", :content => "7fee3f0 hasn't been built yet")
    assert_have_no_tag("h2", :content => "Build Output")
    assert_have_tag("button", :content => "Rebuild")
  end
  
  scenario "Browsing a build with a fixed specified but missing artifact" do
    build = Build.gen(:successful, :commit => Commit.gen(:identifier => "87e673a"))
    Project.gen(:integrity, :builds => [build], :last_build => build, :artifacts => 'artifact')
    
    visit "/integrity"
    click_link(/Build 87e673a/)

    assert_have_tag("h1", :content => "Built 87e673a successfully")
    assert_have_no_tag('h2', :content => 'Artifacts')
  end
  
  scenario "Browsing a build with a fixed specified and existing artifact" do
    build = Build.gen(:successful, :commit => Commit.gen(:identifier => "87e673a"))
    Project.gen(:integrity, :builds => [build], :last_build => build, :artifacts => '2f8375806436491fe106e2151edb0ffd')
    
    build_directory = build.build_directory
    assert !File.exist?(build_directory)
    FileUtils.mkdir_p(build_directory)
    File.open(File.join(build_directory, '2f8375806436491fe106e2151edb0ffd'), 'w') do |f|
      f << 'content2f8375806436491fe106e2151edb0ffd'
    end
    
    visit "/integrity"
    click_link(/Build 87e673a/)

    assert_have_tag("h1", :content => "Built 87e673a successfully")
    assert_have_tag('h2', :content => 'Artifacts')
    # link to artifact
    assert_have_tag('a', :content => '2f8375806436491fe106e2151edb0ffd')
    
    # visit artifact
    click_link(/2f8375806436491fe106e2151edb0ffd/)
    assert_contain('content2f8375806436491fe106e2151edb0ffd')
  end
  
  scenario "Browsing a build with a specified but missing wildcard artifact" do
    build = Build.gen(:successful, :commit => Commit.gen(:identifier => "87e673a"))
    Project.gen(:integrity, :builds => [build], :last_build => build, :artifacts => 'artifact*')
    
    visit "/integrity"
    click_link(/Build 87e673a/)

    assert_have_tag("h1", :content => "Built 87e673a successfully")
    assert_have_no_tag('h2', :content => 'Artifacts')
  end
  
  scenario "Browsing a build with specified and existing wildcard artifacts" do
    build = Build.gen(:successful, :commit => Commit.gen(:identifier => "87e673a"))
    Project.gen(:integrity, :builds => [build], :last_build => build, :artifacts => 'artifact*')
    
    build_directory = build.build_directory
    assert !File.exist?(build_directory)
    FileUtils.mkdir_p(build_directory)
    File.open(File.join(build_directory, 'artifactb46be9dce08b0a5486342b90e732be49'), 'w') do |f|
      f << 'contentb46be9dce08b0a5486342b90e732be49'
    end
    File.open(File.join(build_directory, 'artifactc46b6d4e8839b5eb33f739d47268168a'), 'w') do |f|
      f << 'contentc46b6d4e8839b5eb33f739d47268168a'
    end
    
    visit "/integrity"
    click_link(/Build 87e673a/)

    assert_have_tag("h1", :content => "Built 87e673a successfully")
    assert_have_tag('h2', :content => 'Artifacts')
    # links to artifacts
    assert_have_tag('a', :content => 'b46be9dce08b0a5486342b90e732be49')
    assert_have_tag('a', :content => 'c46b6d4e8839b5eb33f739d47268168a')
    
    # visit artifacts
    click_link(/c46b6d4e8839b5eb33f739d47268168a/)
    assert_contain('contentc46b6d4e8839b5eb33f739d47268168a')
  end
end

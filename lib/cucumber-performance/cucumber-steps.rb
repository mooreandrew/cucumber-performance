require 'timeout'

Given(/^I want to run a performance$/) do

  # This variable prevents any functions being called to produce meta data
  $PERFROMANCETEST = true

  # Result hash for trasctions
  $results_transactions = Hash.new()
  # Result hash for scenarios
  $results_scenarios = Hash.new()

  # Result hash for transctions in a form dumpable for the transactions graph
  $results_transactions_graph = Hash.new()
  # Result hash for scenarios in a form dumpable for the transactions graph
  $results_scenarios_graph = Hash.new()

  # How many v_users are currently running
  $running_v_users = 0

  # V Users change over time, this will keep track every second
  $results_vusers = Hash.new()

  # How long the before one v user finishes and they restart
  $scriptdelaytime = 0

  # Start time of the test
  $starttime = Time.new.to_i

  # How many failures
  $total_failures = 0

  # an Array of error messages
  $error_log = []

  # Start the graph x axes
  $max_x = 3
  $trans_max_x = 3

  # The running scenarios
  $running_scenarios_hash = {}

  # The amount of V users
  $amount_of_users = 0

  # Running v user scenario
  $vuser_scenarios = []

  # How many errors per a scenario
  $scenario_errors = {}

  $scenario_iterations = {}

  $transactions_iterations= {}

  # Start a controller, this is a GUI to allow you to monitor the test.
  # This uses sinatra and is accessable by: http://localhost:4567
  controller_thread = Thread.new{controller}

  @in = StringIO.new
  @out = StringIO.new
  @err = StringIO.new

end

Given(/^I have the following scenarios$/) do |table|

  # This will use the cucumber call above to work out if the scenario you've enter
  # is valid and can be run.

  table.raw.each do |value|

    if value[0] != 'SCENARIO' then
      for i in 0..value[1].to_i - 1
        $vuser_scenarios << value[0]
      end

      $scenario_errors[value[0]] = 0
      $scenario_iterations[value[0]] = 0

      $results_scenarios_graph[value[0]] = []

      $amount_of_users = $amount_of_users + value[1].to_i
      $running_scenarios_hash[value[0]] = value[1].to_i

      begin
        load File.expand_path('performanceTests/' +  value[0].gsub('(','').gsub(')', '').gsub(/ /, '_').capitalize.downcase + '.rb')
      rescue Exception=>e
        raise "Unable to load: " + File.expand_path('performanceTests/' +  value[0].gsub('(','').gsub(')', '').gsub(/ /, '_').capitalize.downcase + '.rb')
      end
    end

  end

  $vuser_scenarios.shuffle

end

Given(/^I run for (\d+) minute(s|)$/) do |duration, word|
  # Define the duration of the test
  $duration = duration.to_i * 60
end

Given(/^I ramp up (\d+) user every (\d+) seconds$/) do |rampup_users, rampup_time|
  # The space between each user starts up.
  $ramp_up_time = rampup_time.to_i
  # How many users to start up per every interval defined above.
  $ramp_up_users = rampup_users
end

When(/^I run the performance test$/) do

  # The duration needs adjusting to include the ramp up time
  # This will include the amount of users * interval
  $duration = $duration + ($amount_of_users * $ramp_up_time)

  # creates an array to manage the threads
  threads = Array.new()

  # We need to get a unique list of the performance test names
  $list_of_tests = Array.new()

  # This block of code below loops though each of the v users to get a unique
  # list of test file names
  $vuser_scenarios.each do |value|
    found = false
    for i in 0..($list_of_tests.count - 1)
      if ($list_of_tests[i] == value) then
        found = true
      end
    end
    if (found == false) then
      $list_of_tests << value
    end
  end

  # We need to know which test we're v user we're up to.
  $vuser_inc = 0

  # We now need to start each of the v users as seperate threads
  # This means each vuser can run indepedently
  for i in 0..($amount_of_users - 1)
    # Calls the loadtest() function
    threads.push(Thread.new{loadtest()})
  end

  # Whilst the v users are running, we need to keep track of what the v users are doing
  # This block of code below will keep a count of second how many v users are running
  cur_time = 0

  running = true

  # There is three ways of knowing if the performance testing is still running
  # if the variable running is true (this gets set to valse when $running_v_users goes above 0, meaning the test has started)
  # The current time is less than the start time plus the duration
  # #running_v_users is above 0

  while (((Time.new.to_i) < ($starttime + $duration)) || ($running_v_users > 0) || (running == true)) do

    # Increase current time by 1 (1 second)
    cur_time = cur_time + 1

    # $graph_time is the yavis max, as v users exit, this can go above the
    # duration, so this expands the yaxis
    $graph_time = $duration
    if (cur_time > $duration) then
      $graph_time = cur_time
    end

    # Build the $results_vusers with the current amount of running v users
    for i in 0..((Time.new.to_i - $starttime + 1))
      if ($results_vusers[i + 1].nil? == true) then
        $results_vusers[i + 1] = $running_v_users
      end
    end

    # If $running_v_users is above 0, set the value to true
    if ($running_v_users == 0) then
      running = false
    else
      running = true
    end

    # sleep for a second
  	sleep(1)

  end

  # Joining threads means the system will wait for them to finish. This means the v users stop
  for i in 0..($amount_of_users - 1)
     threads[i].join
  end

  # Once the performance test has finished the sinatra app stops,
  # this gets around that by visiting the page and producing a pdf output
  visit('http://localhost:4567')
  sleep(1)
  save_screenshot("performance-#{Time.new.to_i}.pdf")

end

Then(/^I expect less than (\d+) failures$/) do |failures|
  # Checks if the total failures is below the threadhold.
  assert_operator $total_failures, :<, failures.to_i, 'The failures weren\'t below the threshold'
end

Then(/^the scenarios response times were below:$/) do |table|
  # Loop through each of the scenarios to see if they were below the threshold
  table.raw.each do |value|
    if (value[0] != 'SCENARIO')
      # We need to get the average of the scenarios and then devide that by 1000 because they are in miliseconds
      response_time = ($results_scenarios[value[0]].inject{ |sum, el| sum + el }.to_f / $results_scenarios[value[0]].size) / 1000
      # Assert to see if the response time is below the threshold
      assert_operator response_time, :<, value[1].to_i, 'The average response time wasn\'t below the threshold (' + value[0] + ')'
    end
  end

end

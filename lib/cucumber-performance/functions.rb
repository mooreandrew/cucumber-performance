#####
## Function: loadtest
## Inputs: None
## Outputs: None
## Description: This function should be called when a v user thread is created,
##              this will open the scripts in steps_definitions\performance
##              and run the v_action() in there.
#####
def loadtest()

  # Redirect $stdout (Console output) to nil

  # Workout the delay time of the script
  $scriptdelaytime = $scriptdelaytime + $ramp_up_time

  # Sleep for that delay time, so we can start ramping up users incrementally
  sleep $scriptdelaytime

  # Get which cucumber scenario by using the $vuser_inc variable.
  cucumber_scenario = $vuser_scenarios[$vuser_inc]
  # Increase this variable by 1 so the other scenarios can use it
  $vuser_inc = $vuser_inc + 1

    # convervate the cucumber scenario name, into the class name
    scenario_name = cucumber_scenario.gsub('(','').gsub(')', '').gsub(/ /, '_').capitalize

    # create an instance of the class from the (step_defitions/performance) file
    script = Module.const_get(scenario_name).new

    # Increase the variable which keeps track of running virtual users
    $running_v_users = $running_v_users + 1

    iteration = 0

    # Loop through for the duration of the test, this will run the test each time it loops
    while ((Time.new.to_i)  < ($starttime + $duration)) do

      iteration += 1

      # Works out the start time of the current test (iteration)
      scriptstart_time = Time.now

      # We'll run the test in a try/except block to ensure it doesn't kill the thread
      begin
        # Call the threads action step
        script.v_action()

        # As the test has finished, work out the duration
        script_duration = (Time.now - scriptstart_time) * 1000

        # If the duration is above the x axis current value, let's increase it
        if ((script_duration / 1000) > $max_x) then
          $max_x = (script_duration / 1000).ceil + 1
        end

        # If the current cucumber scenario have no results, lets define their arrays
        if ($results_scenarios[cucumber_scenario].nil?) then
          $results_scenarios[cucumber_scenario] = []
          $results_scenarios_graph[cucumber_scenario] = {}
        end

        # Add the duration of the test to an array so we can work our max/min/avg etc...
        $results_scenarios[cucumber_scenario] << script_duration

        # For each second we need to build up an average, so need to build up another array
        # based on the current time
        current_time_id = $duration - (($starttime + $duration) - Time.new.to_i) + 1

        # If the array doesn't exist for the current time, then lets define it
        if($results_scenarios_graph[cucumber_scenario][current_time_id].nil? == true) then
          $results_scenarios_graph[cucumber_scenario][current_time_id] = Array.new()
        end

        # Add the value to the array
        $results_scenarios_graph[cucumber_scenario][current_time_id].push(script_duration)

      rescue Exception=>e
        # If it fails, keep a log of why, then carry on

        error = {}
        error['error_message'] = e.to_s + '<br>' + e.backtrace.to_s
        error['error_iteration'] = iteration
        error['error_script'] = cucumber_scenario

      #  $stdout.puts 'Error: ' + e + "\n" +  backtrace.map {|l| "  #{l}\n"}.join


        $scenario_errors[cucumber_scenario] += 1

        #$stdout.puts $scenario_errors

        $error_log << error

        $total_failures += 1
      #  $stdout.puts 'Error: ' + e + "\n" +  backtrace.map {|l| "  #{l}\n"}.join
      end

      $scenario_iterations[cucumber_scenario] += 1


      # Sleep a second between each scenario. This will need to be parametised soon
      sleep(1)

    end
    # Once the test has finished, lets decrease the $running_v_users value
    $running_v_users = $running_v_users - 1

end



#####
## Function: start_traction
## Inputs: step_name (String)
## Outputs: current time (dateTime)
## Description: This is to get the time at a certain points to work out the
##              response time of certain parts of the load test
#####
def start_traction(step_name)

  scriptstart_time = Time.now

end

#####
## Function: start_traction
## Inputs: step_name (String)
## Outputs: current time (dateTime)
## Description: This is to get the time at a certain points to work out the
##              response time of certain parts of the load test
#####
def end_traction(step_name, start_time)

  if ($transactions_iterations[step_name].nil?) then
    $transactions_iterations[step_name] = 0
  end

  $transactions_iterations[step_name] += 1

  # This uses the value from start_traction() and finds how long the test took.
  transaction_duration = (Time.now - start_time) * 1000

  # If the current transaction have no results, lets define their arrays
  if ($results_transactions[step_name].nil?) then
    $results_transactions[step_name] = []
    $results_transactions_graph[step_name] = {}
  end

  # Add the duration of the test to an array so we can work our max/min/avg etc...
  $results_transactions[step_name] << transaction_duration

  # For each second we need to build up an average, so need to build up another array
  # based on the current time
  current_time_id = $duration - (($starttime + $duration) - Time.new.to_i) + 1

  # If the array doesn't exist for the current time, then lets define it
  if($results_transactions_graph[step_name][current_time_id].nil? == true) then
    $results_transactions_graph[step_name][current_time_id] = Array.new()
  end

  # Add the value to the array
  $results_transactions_graph[step_name][current_time_id].push(transaction_duration)

end

#####
## Function: http_get
## Inputs: curl (Curl::Easy Instance) data (Hash of headers) url (String of the url)
## Outputs: current time (dateTime)
## Description: Performs a http get command for the user specified
#####
def http_get(curl, data, url)

  # Define the url we want to hit
  curl.url=url

  # Specify the headers we want to hit
  curl.headers = data['header']

  # perform the call
  curl.http_get

  # Set headers to nil so none get reused elsewhere
  curl.headers = nil

  # return the curl object
  return curl
end

#####
## Function: http_post
## Inputs: curl (Curl::Easy Instance) data (Hash of headers and posts) url (String of the url)
## Outputs: current time (dateTime)
## Description: Performs a http get command for the user specified
#####
def http_post(curl, data, url)

  # Define the post data
  data2 = ''

  # Loop through the data["post_data"] passed in to build up the post data string
  data["post_data"].each do |key, value|
    if (data2 != '') then
      data2 = data2 + '&'
    end
    # If the value is null we don't just want it to look like: item=
    if (value.nil?) then
      data2 = data2 + CGI::escape(key.to_s) + '='
    else
      data2 = data2 + CGI::escape(key.to_s) + '=' + CGI::escape(value.to_s)
    end
  end

  # Define the url we want to hit
  curl.url = url
  # Specify the headers we want to hit
  curl.headers = data['header']

  # perform the call
  curl.post(data2)

  curl.headers = nil

  # Set headers to nil so none get reused elsewhere
  curl.headers = nil

  # return the curl object
  return curl

end

#####
## Function: assert_http_status
## Inputs: curl (Curl::Easy Instance) status (expected http status code)
## Outputs: current time (dateTime)
## Description: Performs a http get command for the user specified
#####
def assert_http_status(curl, status)

  # If the status doesn't match, then raise an exception
  if (curl.response_code != status) then
    raise  curl.url + ': Expected response of ' + status.to_s + ' but was ' + curl.response_code.to_s
  end
end


#####
## Function: controller
## Inputs: None
## Outputs: None
## Description: This is the controller thread for running the sinatra app, monitoring the run
#####
def controller()

  # Create a Sinatra isntance
  $sinatra_instance = Sinatra.new()

  # Get a localhost/data url defined (used by ajax)
  $sinatra_instance.get '/data' do

    # we need to turn the data object into a json response at the end
    data = {}

    # This is the array of data for each scenario for the graph
    data['graph_data'] = []

    # The array for the erros
    data['error_log'] = $error_log

    # Define the graph data objects
    for i in 0..10
      data['graph_data'][i] = []
    end

    # Work out the xmax and ymax
    data['graph_xmax'] = (($graph_time || 0) * 1.05).ceil.to_s
    data['graph_ymax'] = (($amount_of_users || 0) * 1.2).ceil.to_s

    # Sets the graph data for [0] (vusers) to 0, stops an error
    data['graph_data'][0][0] = 0

    if (!$starttime.nil?) then

      # Loops through each second to get the graph data
      for i in 0..((Time.new.to_i - $starttime ))

        # The [0] is for v users
        data['graph_data'][0][i] = $results_vusers[i + 1]

        num = 0
        # Anthing above [0] is for the running tests
        $results_scenarios_graph.each do |key, results2|
          num = num + 1
          if (results2[i + 1].nil? == false) then

            sum = 0
            results2[i + 1].each { |a| sum+=a }

            # Add the results to the json object
            data['graph_data'][num][i] = ((sum / results2[i + 1].size.to_f) / 1000).round(2)

            if (data['graph_data'][num][i] > $max_x) then
              $max_x = data['graph_data'][num][i]
            end

          end
        end
      end
    end

    data['graph_y2max'] = ($max_x * 1.1)

    # Define the objects for the overview of the cucumber scenarios (table below graph)
    data['graph_details_name'] = []
    data['graph_details_min'] = []
    data['graph_details_max'] = []
    data['graph_details_avg'] = []
    data['graph_details_err'] = []
    data['graph_details_ite'] = []
    data['graph_details_per'] = []

    data['graph_details_name'][0] = 'Vusers'

    # If the data exists then use it, otherwise set it to 0
    if (!data['graph_data'].nil?) then

      if (data['graph_data'][0].nil?) then
        data['graph_data'][0] = []
      end

      if (data['graph_data'][0].count > 1)
        data['graph_details_avg'][0] =  (data['graph_data'][0].inject{ |sum, el| sum + el }.to_f / data['graph_data'][0].size).round(2)
        data['graph_details_min'][0] = data['graph_data'][0].min.round(2)
        data['graph_details_max'][0] = data['graph_data'][0].max.round(2)
      else
        data['graph_details_avg'][0] = 0
        data['graph_details_min'][0] = 0
        data['graph_details_max'][0] = 0
      end

      data['graph_details_err'][0] =  0
      data['graph_details_ite'][0] =  0
      data['graph_details_per'][0] = 0

    else
      data['graph_details_min'][0] = 0
      data['graph_details_max'][0] = 0
      data['graph_details_avg'][0] = 0
      data['graph_details_err'][0] =  0
      data['graph_details_ite'][0] =  0
      data['graph_details_per'][0] = 0

    end

    i = 0
    #puts $results_scenarios_graph.count
    # This is the same as above, but for tests, not the vusers
    $results_scenarios_graph.each do |key, results2|

      i += 1
      data['graph_details_name'][i] = key

      if (!$results_scenarios[key].nil?) then

        if ($results_scenarios[key].count > 1)
          data['graph_details_avg'][i] = (($results_scenarios[key].inject{ |sum, el| sum + el }.to_f / $results_scenarios[key].size) / 1000).round(2)
          data['graph_details_min'][i] = ($results_scenarios[key].min / 1000).round(2)
          data['graph_details_max'][i] = ($results_scenarios[key].max / 1000).round(2)
          data['graph_details_per'][i] = (percentile($results_scenarios[key], 0.9) / 1000).round(2)
        else
          data['graph_details_avg'][i] = 0
          data['graph_details_min'][i] = 0
          data['graph_details_max'][i] = 0
          data['graph_details_per'][i] = 0
        end
      else

        data['graph_details_min'][i] = 0
        data['graph_details_max'][i] = 0
        data['graph_details_avg'][i] = 0
        data['graph_details_per'][i] = 0

      end

      data['graph_details_err'][i] = $scenario_errors[key]
      data['graph_details_ite'][i] = $scenario_iterations[key]


    end














    # This is the array of data for each scenario for the graph
    data['trans_graph_data'] = []

    # Define the graph data objects
    for i in 0..30
      data['trans_graph_data'][i] = []
    end

    # Work out the xmax and ymax
    data['trans_graph_xmax'] = (($graph_time || 0) * 1.05).ceil.to_s

    # Sets the graph data for [0] (vusers) to 0, stops an error

    #$stdout.puts $results_transactions_graph

    if (!$starttime.nil?) then

      # Loops through each second to get the graph data
      for i in 0..((Time.new.to_i - $starttime ))

        num = 0
        # Anthing above [0] is for the running tests
        $results_transactions_graph.each do |key, results2|
          if (results2[i + 1].nil? == false) then

            sum = 0
            results2[i + 1].each { |a| sum+=a }

            # Add the results to the json object
            data['trans_graph_data'][num][i] = ((sum / results2[i + 1].size.to_f) / 1000).round(2)
            if (data['trans_graph_data'][num][i] > $trans_max_x) then
              $trans_max_x = data['trans_graph_data'][num][i]
            end

          end
          num = num + 1
        end
      end
    end

    data['trans_graph_ymax'] = ($trans_max_x * 1.1)

    data['trans_graph_details_name'] = []
    data['trans_graph_details_min'] = []
    data['trans_graph_details_max'] = []
    data['trans_graph_details_avg'] = []
    data['trans_graph_details_err'] = []
    data['trans_graph_details_ite'] = []
    data['trans_graph_details_per'] = []

    i = 0
    #puts $results_transactions_graph.count
    # This is the same as above, but for tests, not the vusers
    $results_transactions_graph.each do |key, results2|


      data['trans_graph_details_name'][i] = key

      if (!$results_transactions[key].nil?) then

        if ($results_transactions[key].count > 1)
          data['trans_graph_details_avg'][i] = (($results_transactions[key].inject{ |sum, el| sum + el }.to_f / $results_transactions[key].size) / 1000).round(2)
          data['trans_graph_details_min'][i] = ($results_transactions[key].min / 1000).round(2)
          data['trans_graph_details_max'][i] = ($results_transactions[key].max / 1000).round(2)
          data['trans_graph_details_per'][i] = (percentile($results_transactions[key], 0.9) / 1000).round(2)
        else
          data['trans_graph_details_avg'][i] = 0
          data['trans_graph_details_min'][i] = 0
          data['trans_graph_details_max'][i] = 0
          data['trans_graph_details_per'][i] = 0
        end
      else

        data['trans_graph_details_min'][i] = 0
        data['trans_graph_details_max'][i] = 0
        data['trans_graph_details_avg'][i] = 0
        data['trans_graph_details_per'][i] = 0

      end

      if (!$transactions_iterations[key].nil?)
        data['trans_graph_details_ite'][i] = $transactions_iterations[key]
      else
        data['trans_graph_details_ite'][i] = 0
      end
      i += 1
    end



    # Print the output as a json string
    return data.to_json
  end

  # Get a localhost url defined (main page)
  $sinatra_instance.get '/' do

    erb :'index.html'

  end

  # run sinatra on the default url/port
  $sinatra_instance.run!

end

def percentile(values, percentile)
    values_sorted = values.sort
    k = (percentile*(values_sorted.length-1)+1).floor - 1
    f = (percentile*(values_sorted.length-1)+1).modulo(1)

    return values_sorted[k] + (f * (values_sorted[k+1] - values_sorted[k]))
end

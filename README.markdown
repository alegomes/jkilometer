JKilometer - boosting JMeter tests
==================================

What is it?
-----------
Jkilometer is a set os BASH scripts developed to help us on benchmarking Java apps with Jakarta JMeter tool.

How to use it
-------------
* Simplest use

 	./jkm.sh -t MyTestPlan.jmx -T 20 -r 2


Motivation
----------
So, we use JMeter for years. We already know how to get the best of it, right? We use it to simulate access on web apps usually to perform any sort of tuning. We are senior developers/sysadmins and, as such, we feel when something is going wrong. We can smell thread blockings. We guess memory leaks and dream with 'TooManyOpenFiles'-like issues. Well, at least, that's how I see people getting tunings done.

Usually, perf tests lacks structured data. When tuning an environment, people underestimates the need of collect metrics in such a way that graphical analisys could be handled to generate clear conclusions. 

You know what? I'm not the best person to talk about all this stuff. I'm sure you can find better content out there. Just google for performance tests or even benchmarking strategies. The point is we need to gather data. And we need consistent data across every step made on the test cycle.

We need to know how the server memory (or system load, or blocked procs) are during a test execution. We also must follow the test execution and

How to use it
-------------

Download both script, jkm.sh and jkmagent.sh. The former is the client test. It interacts to JMeter to start a given test, monitor its execution and merge its data to metrics collected from the tested server. The second script, jkmagent.sh, is the guy responsible to collect metrics on a Java app server and send it to jkm.sh as resquested.

Need more help?
---------------
Try *./jkm.sh -h* and get

  	Usage:  ./jkm.sh -t <jmeter_script.jmx> -T <num_of_threads> -r <ramp_up> [-S <appserver_address>] [-R ip1,ip2,ip3...] [-c comment] | -s | -h?

         ** MASTER MODE **

           Required Arguments
           -------------------
           -t A JMeter test plan JMX file

           -T The number of threads to run the test plan

           -r The time (in seconds) JMeter has to start all the specified threads

           Optional Arguments
           -------------------
           -S The Java server you wish to monitor during the test plan execution (jkmagent.sh needed)

           -R Set of JMeter Slaves addresses to help on test plan execution

           -c A useful comment to distinguish previous test execution from the next one

         ** SLAVE MODE **

           -s Start JMeter in slave mode for remote testing (see http://jakarta.apache.org/jmeter/usermanual/remote-test.html)

         ** HELP MODE **

           -h or -? Prints this help message.

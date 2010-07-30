JKilometer - boosting JMeter tests
==================================

What is it?
-----------
Jkilometer is a set os BASH scripts developed to help us on benchmarking Java apps with Jakarta JMeter tool.

How to use it
-------------
* Starting 20 threads in 2 seconds to execute MyTestPlan.jxm   
 	
		./jkm.sh -t MyTestPlan.jmx -T 20 -r 2

* Now, monitoring server's behavior

		./jkm.sh -t MyTestPlan.jmx -T 20 -r 2 -S 10.9.8.7
		
* Re-executing the test after changing JVM's -Xmx argument

		./jkm.sh -t MyTestPlan.jmx -T 20 -r 2 -S 10.9.8.7 -c "Increased Tomcat's -Xmx to 8Gb"

What's the big deal?
--------------------
Instead of just running a test plan, as JMeter does, it's also capable of collecting any metric you want from tested servers and merge it with JMeter test results to generate a comprehensive mass of data.

Disclaimer
----------
I made it to my personal use and it #WORKSFORME. So, use it at your own risk. Don't blame me if it's not so well designed or as flexible as you wish. And please, be my guest to fork it and make it better.

Motivation
----------
So, we use JMeter for years. We already know how to get the best of it, right? We use it to simulate access on web apps usually to perform any sort of tuning. We are senior developers/sysadmins and, as such, we feel when something is going wrong. We can smell thread blocking. We guess memory leaks and dream with 'TooManyOpenFiles'-like issues. Well, at least, that's how I see people getting tunings done.

Usually, perf tests lacks structured data. When tuning an environment, people underestimates the need to collect metrics in such a way that graphical analysis could be handled to generate clear conclusions. 

Yes, I know JMeter can generate some metrics and even collect data from tested servers. But, as far as I know, it's limited (based on Tomcat's Manager application). I didn't realize yet any way to get fine grained infos from tested servers during a load test execution. We need to know how does the server memory works, the system load and how many blocked threads exists during the test lifecycle. Well, I do know how to get all these data using SSH and Unix commands. The point is I've never found an out-of-the-box feature to synchronize this remote data to JMeter results. And that's why I've developed this BASH scripts. It aims to wrap JMeter execution, collect remote data during the testing process and compile it as a single and integrated unit.

But I'm not the best person to talk about all this stuff. I'm sure you can find better content out there. Just google for performance tests or even benchmarking strategies. The point is we need to gather data. And we need consistent data across every step made on the test cycle.

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


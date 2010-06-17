JKilometer - Boosting JMeter tests
==================================

What is it?
-----------
Jkilometer is a set os BASH scripts developed to help us on performance tuning tasks.

Motivation
----------
So, we use JMeter for years. We already know how to get the best of it, right? We use it to simulate access on web apps usually to perform any sort of tuning. We are senior developers/sysadmins and, as such, we feel when something is going wrong. We can smell thread blockings. We guess memory leaks and dream with 'TooManyOpenFiles'-like issues. Well, at least, that's how I see people getting tunings done.

Usually, perf tests lacks structured data. When tuning an environment, people underestimates the need of collect metrics in such a way that graphical analisys could be handled to generate clear conclusions. 

You know what? I'm not the best person to talk about all this stuff. I'm sure you can find better content out there. Just google for performance tests or even benchmarking strategies. The point is we need to gather data. And we need consistent data across every step made on the test cycle.

We need to know how the server memory (or system load, or blocked procs) are during a test execution. We also must follow the test execution and

How to use it
-------------

Download both script, jkm.sh and jkmagent.sh. The former is the client test. It interacts to JMeter to start a given test, monitor its execution and merge its data to metrics collected from the tested server. The second script, jkmagent.sh, is the guy responsible to collect metrics on a Java app server and send it to jkm.sh as resquested.

#Get a list of servers to build, prompt user to choose individual IP address or csv file

#Call iDrac setup script, should handle everything up through mounting the ISO, pass the list of IPs to it

#At this stage the server boots and the image is installed, it takes an hour, maybe figure out a way for the script to check status every x minutes and then proceed once imaging is complete

#Now the OS needs to be configured, I haven't yet automated most of those tasks, on my todo list, so pause with the option to resume once OS has been configured

#Then we're into the NW config, push services with orchestration client, install updates

#Enable SSL on the rest api

#Change the admin password

#Replicate roles

#Configure storage

#Configure aggregation/capture

#Produce a verification report for all hosts once the build is complete

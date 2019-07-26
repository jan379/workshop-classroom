
# student classroom infrastructure as code

Imagine you want to demonstrate some kubectl features to a class 
of students. All of them have a wild mix of OS', Desktop environments
and skill level. Until every one of them has kubectl set up on
there PCs your time is over. That is where these template kicks in:

openstack stack create -t clustersetup.yaml classroom-$(date +%F)

èt voila: your classroom is set up and ready to be used.



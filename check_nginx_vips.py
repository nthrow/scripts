# This check validates that all VIPs in valid configuration are active in the live upstreams API.
#!/bin/sh # crunchbang for python3 agnosticism
''''which python3 &>/dev/null && exec python3 "$0" # '''
''''which python3.4 &>/dev/null && exec python3.4 "$0" # '''
''''which python3.6 &>/dev/null && exec python3.6 "$0" # '''
''''echo "WARN: is python3 installed on this host?" && exit 1 # '''

# import required python modules
import json, os, re, requests

# function to retrieve loadbalancer API address
def apiAddress():
  # compile regex for listen directive
  lisRgx = re.compile(r'listen\s+(10.(?:\d{1,3}\.){2}\d{1,3}):80;')
  # parse api.conf for listen directive
  try:
    with open('/etc/nginx/conf.d/http/api.conf', 'r') as apiConf:
      for line in apiConf:
        apiAddr = lisRgx.search(line)
        if apiAddr is not None:
          return apiAddr.group(1)
  # if no match, exit helpfully
  except IOError:
    print("WARN: does api.conf exist on this host?")
    os._exit(1)

# function to list upstreams active in the API
def apiUpstreams(apiAddr):
  # query API and store the response as a JSON object
  response = requests.get('http://' + apiAddr + '/api/4/http/upstreams')
  upstreams = json.loads(response.text)
  # parse api response and return as list
  vipList = []
  for vip in upstreams:
    vipList.append(vip)
  # if no matches, exit helpfully
  if vipList: return vipList
  else: print("WARN: is the API actually responsive?"); os._exit(1)

# function to list configured upstreams
def confUpstreams():
  # setting basic variables
  confDir = '/etc/nginx/conf.d/http/'
  upsRgx = re.compile(r'^upstream\s(((\w+-)+)\w+)\s{$')
  vipList = []
  # parse configuration directory for active upstreams
  for filename in os.listdir(confDir):
    if filename.endswith('.conf', 5) == True: # ensure we don't check backup configs
      with open(confDir + filename, 'r') as upsConf:
        for line in upsConf:
          upstream = upsRgx.match(line)
          if upstream is not None:
              vipList.append(upstream.group(1))
  # if no matches, exit helpfully
  if vipList: return vipList
  else: print("WARN: are there any upstream config files?"); os._exit(1)

def main():
  # gather and sort data
  address = apiAddress()
  apiSet = set(apiUpstreams(address)) # a set, since we're just concerned with membership
  confList = confUpstreams(); confList.sort() # a sorted list, for cleanliness
  # compare the two collections
  matches = [i for i, upstream in enumerate(confList) if upstream in apiSet]
  # sort and handle the results
  if len(matches) == len(confList): print("OKAY: All VIPs are currently active!")
  else: print("CRIT: One or more configured VIPs are not yet active!"); os._exit(2)

main()

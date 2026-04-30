#!/usr/bin/env python3
import datetime, json, requests, socket, time

API_URL = 'https://api.pagerduty.com/incidents/'
API_VER = 'application/vnd.pagerduty+json;version=2'
API_AUTH = 'Token token=oRwmHo4ApX_BH7j_p1CZ='

d = datetime.datetime.now()
p = d - datetime.timedelta(minutes = 5)
endTime = d.strftime('%Y-%m-%d') + 'T%3A' + d.strftime('%H') + '%3A' + d.strftime('%M') + '%3A' + d.strftime('%S') + 'Z'
startTime = p.strftime('%Y-%m-%d') + 'T%3A' + p.strftime('%H') + '%3A' + p.strftime('%M') + '%3A' + p.strftime('%S') + 'Z'

def dumpIncs(teamID,servID):
  queStr = ('?since=' + startTime + '&until=' + endTime + # define time window
  '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged&statuses%5B%5D=resolved' + # grab all statuses
  '&service_ids%5B%5D=' + servID + '&team_ids%5B%5D=' + teamID + # target service and its team
  '&urgencies%5B%5D=high&urgencies%5B%5D=low&time_zone=UTC' + # urgencies & utc
  '&include%5B%5D=services&include%5B%5D=teams&include%5B%5D=assignees&include%5B%5D=acknowledgers&include%5B%5D=priorities')
  req = requests.get(API_URL + queStr, headers={
    "Accept": API_VER,
    "Authorization": API_AUTH
  })
  results = json.loads(req.text)
  return results

def shipIncs(results):
  for incident in results['incidents']:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(None)
    sock.connect(("127.0.0.1", 514))
    time.sleep(0.025)
    sock.sendall(json.dumps(incident).encode('utf-8'))
#    print(json.dumps(incident).encode('utf-8'))
    time.sleep(0.025)
    sock.close()

def main():
  directory = {
    'PQQT2LN': ['PSCXCPK'], # Media Ops Services
    'PQSNMLD': ['P75EM78', 'P12ER2N'], # NetOps Role
    'PQN4R13': ['P1VES0B', 'P0FZ5H8', 'P260CRG', 'PD8IXTJ', 'PS1E3IV', 'P3TEPMF', 'P8XUR26', 'PG9TNQM' ], # Skynet Media Framework
    'PS5ALPR': ['PG9RSS6', 'PJJ90AB', 'PV6IOZP', 'PV0C1OO', 'PXS7299' ] # SysOps
  }
  for teamID in directory:
    for servID in directory[teamID]:
      results = dumpIncs(teamID,servID)
      shipIncs(results)

main()

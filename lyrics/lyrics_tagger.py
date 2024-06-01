import glob
import eyed3
import urllib3
from bs4 import BeautifulSoup
from urllib.parse import quote
import json

fileNames = glob.glob("*.mp3")
for name in fileNames:
    try:
        audiofile = eyed3.load((name))
        name= name.replace('.mp3','')
        songName = quote(audiofile.tag.title)
        artistName = quote(audiofile.tag.artist)
        url = "https://lyrist.vercel.app/api/"+ songName + "/" + artistName
        http = urllib3.PoolManager()
        response = http.request("GET", url)
        lyrics = json.loads(response.data.decode("utf-8"))['lyrics']
        audiofile.tag.lyrics.set(lyrics)
        audiofile.tag.save()
        print('lyrics Added for ' + name)
    except :
        print ('An error occured for ' + name)

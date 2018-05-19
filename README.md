# BTL-viewer
[Elasticsearch](https://github.com/elastic/elasticsearch) based full text research portal for [DeGruyter](https://www.degruyter.com/)'s [Bibliotheca Teubneriana Latina](https://www.degruyter.com/view/db/btl) (the offline XML files)

Developed by [Thomas Efer](https://github.com/efi) as part of the project [eXChange](https://github.com/exchange-projekt) with funding from the [Federal Ministry of Education and Research](https://www.bmbf.de/).

## Features
  * web based
  * password protected
  * small
  * exposes lots of full text query options
    * truncated search:<br/>`*pileps*`
    * author filtering:<br/>`morb* AND author:Polemius`
    * title filtering:<br/>`clade* AND title:retract*`
    * phrases:<br/>`"quid est epistola"`
    * logical NOT:<br/>`clavicula AND !clavis`
    * distance search:<br/>`"thales milesius"~2`
  * shows document similarity within the collection

## Prerequirements
 * server system capable of running ~~Ruby or~~ JRuby<br /><sup>_(Under Ruby the SAX parser cannot resolve external Entities, so either change the sources or use JRuby)_</sup>
 * Ruby gem `bundler` installed
 * Elasticsearch installed, running and locally listening on the default port
 * the XML files from DeGruyter (not included), e.g. from `BTL_CurrentData_20120212.zip`: <pre>
Agricola_00001.xml Asterius_00001.xml BTL_OUT_2011-01_modified_20140212.xml BTL_OUT_2011-02.xml BTL_OUT_2011-03.xml BTL_OUT_2011-04.xml BTL_OUT_2011-05.xml BTL_OUT_2011-06.xml BTL_OUT_2011-07_modified_20140212.xml BTL_OUT_2011-08.xml BTL_OUT_2011-09.xml BTL_OUT_2011-10.xml BTL_OUT_2011-11.xml BTL_OUT_2011-12.xml BTL_OUT_2011-13.xml BTL_OUT_2011-14.xml BTL_OUT_2011-15.xml BTL_OUT_2011-16_modified_20140212.xml BTL_OUT_2011-17.xml BTL_OUT_2011-18.xml BTL_OUT_2011-19.xml BTL_OUT_2011-20.xml BTL_OUT_2011-21.xml BTL_OUT_2011-22.xml BTL_OUT_2011-23.xml BTL_OUT_2011-24.xml BTL_OUT_2011-25.xml BTL_OUT_2011-26.xml BTL_OUT_2011-27.xml BTL_OUT_2011-28.xml BTL_OUT_2011-29.xml BTL_OUT_2011-30.xml BTL_OUT_2011-31.xml BTL_OUT_2011-32.xml BTL_OUT_2011-33.xml BTL_OUT_2011-34.xml BTL_OUT_2011-35.xml BTL_OUT_2011-36.xml Curtius_00001.xml Lactantius_Fasc3.xml Lactantius_Fasc4.xml Vergil_00001.xml</pre></details>

## Setup and startup
Run `bundle install` followed by `ruby indexer.rb` and finally `ruby portal.rb`
  
## License
The specific open-source license model is yet to be decided. For now you are free to view the code, download and use the software, make changes to the software and run the changed software. For public re-distribution of the changed code, please contact the author first.

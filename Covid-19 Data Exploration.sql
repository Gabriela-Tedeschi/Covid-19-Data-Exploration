/*
Covid-19 Data Exploration
Desc: Exploring a dataset from Our World in Data that tracks Covid-19 cases, deaths, and vaccinations by country over time.
	- Includes data from 1/01/20 through 9/28/21
	- The table covid_deaths includes data related to cases and deaths
	- The table covid_vaccinations includes data related to vaccinations and hospital bedspace
*/

Use Portfolio_Project;

-- Show U.S. deaths as percentage of cases over time
Select
	date,
	total_cases,
	total_deaths,
	(total_deaths/total_cases) * 100 as [deaths_per_100_cases]
From covid_deaths
Where location = 'United States'
Order By date;


-- Show U.S. deaths as percentage of population over time
Select
	date,
	total_cases,
	total_deaths,
	population,
	(total_deaths/population) * 100 as [population_death_rate]
From covid_deaths
Where location = 'United States'
Order By date;


-- Join tables to show case, death, and vaccination data for U.S. over time
Select
	cd.date,
	cd.total_cases,
	cd.total_deaths,
	cv.people_vaccinated,
	cv.people_fully_vaccinated
From covid_deaths As cd
Join covid_vaccinations As cv
	On cd.location = cv.location
	And cd.date = cv.date
Where cd.location = 'United States';


-- Show countries in 95th percentile for cases per 100 people (as of 9/28/21)
	-- Note: exclude rows where continent is null as they include multiple countries
Select Top (5) percent
	location,
	population,
	total_cases,
	(total_cases/population) * 100 as [total_cases_per_100_people]
From covid_deaths
Where
	date = '2021-09-28'
	And continent Is Not Null
Order By (total_cases/population) * 100 Desc;


-- Show countries with lower total cases per 100 people than U.S. at the end of 2020 (using subquery)
Select
	location,
	(total_cases/population) * 100 as [total_cases_per_100_people]
From covid_deaths
Where
	date = '2020-12-31'
	And (total_cases/population) < 
			(Select (total_cases/population)
			From covid_deaths 
			Where 
				location = 'United States'
				And date = '2020-12-31')
	And continent is Not Null
Order By (total_cases/population) * 100 Desc;


-- Show countries with higher vaccination rate than U.S. in mid 2021 (using user-defined functions)
	-- UDF that provides the vaccination rate in the U.S. on a given date
Create Function dbo.fGetUSVaccRate (@Date date)
Returns float
As
Begin
	Return (Select (people_fully_vaccinated/population)
			From covid_vaccinations
			Where location = 'United States'
			And date = @Date);
End

	-- Query using UDF
Select
	location,
	(people_fully_vaccinated/population) * 100 as [fully_vaccinated_rate]
From covid_vaccinations
Where 
	date = '2021-07-01'
	And (people_fully_vaccinated/population) > dbo.fGetUSVaccRate('2021-07-01')
	And continent is Not Null
Order By (people_fully_vaccinated/population) * 100 Desc;


-- Show average of countries' hopsital beds per thousand
Select
	AVG(hospital_beds_per_thousand) as [global_avg_hospital_beds_per_thousand]
From covid_vaccinations
Where 
	continent is Not Null
	And date = '2021-09-28';


-- Show average national death rate
Select
	AVG(total_deaths/population) * 100 as [global_avg_natl_death_rate]
From covid_deaths
Where 
	continent is Not Null
	And date = '2021-09-28';


-- Create a temp table that labels countries as above average and below average for hopsital beds and death rate
	-- Create UDFs
Create Function dbo.fGetAvgHospitalBeds (@Date date)
Returns float
As
Begin
	Return (Select AVG(hospital_beds_per_thousand)
			From covid_vaccinations
			Where 
				continent is Not Null
				And date = @Date);
End

Create Function dbo.fGetAvgNatlDeathRate (@Date date)
Returns float
As
Begin
	Return (Select AVG(total_deaths/population) * 100
			From covid_deaths
			Where 
				continent is Not Null
				And date = @Date);
End

	-- Create temp table
Create Table #temp_hospitalbeds_deathrate (
	location nvarchar(100),
	hospital_beds_per_thousand float,
	hospital_bed_status nvarchar(100),
	death_rate float,
	death_rate_status nvarchar(100)
	);

Insert Into #temp_hospitalbeds_deathrate
	Select
		cd.location,
		cv.hospital_beds_per_thousand,
		Case When cv.hospital_beds_per_thousand >= dbo.fGetAvgHospitalBeds('2021-09-28')
			Then 'AboveAvg'
			Else 'BelowAvg'
		End as hospital_bed_status,
		(cd.total_deaths/cd.population) * 100 as death_rate,
		Case When (cd.total_deaths/cd.population) * 100 >= dbo.fGetAvgNatlDeathRate('2021-09-28')
			Then 'AboveAvg'
			Else 'BelowAvg'
		End as death_rate_status
	From covid_deaths as cd
	Join covid_vaccinations as cv
		On cd.location = cv.location
		And cd.date = cv.date
	Where 
		cd.continent is Not Null
		And cv.hospital_beds_per_thousand is Not Null
		And (cd.total_deaths/cd.population) is Not Null
		And cd.date = '2021-09-28';

Select * From #temp_hospitalbeds_deathrate
Order By location;


-- Show average death rate by hospital bed status
Select
	hospital_bed_status,
	AVG(death_rate) as [avg_death_rate]
From #temp_hospitalbeds_deathrate
Group By hospital_bed_status;


-- Show median age and hospital bed and death rate status by location
Select
	cv.location,
	hbd.hospital_bed_status,
	hbd.death_rate_status,
	cv.median_age
From covid_vaccinations as cv
Join #temp_hospitalbeds_deathrate as hbd
	On cv.location = hbd.location
Where
	cv.continent is Not Null
	And cv.median_age is Not Null
	And cv.date = '2021-09-28'
Order By location;


-- Show average median age by hospital bed and death rate status
Select
	hbd.hospital_bed_status,
	hbd.death_rate_status,
	AVG(cv.median_age) as [avg_median_age]
From covid_vaccinations as cv
Join #temp_hospitalbeds_deathrate as hbd
	On cv.location = hbd.location
Where
	cv.continent is Not Null
	And cv.median_age is Not Null
	And cv.date = '2021-09-28'
Group By hbd.hospital_bed_status, hbd.death_rate_status;


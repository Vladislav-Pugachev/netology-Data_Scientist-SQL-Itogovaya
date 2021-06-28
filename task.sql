--Задание №1
--В каких городах больше одного аэропорта?
select distinct (city)
from (select city, count(city) over (partition by city) as sum_airports from airports ) as a
where sum_airports > 1

--Задание №2
--В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?
-- в подзапросе находился самолет с наибольшей дальностью полета
select distinct (departure_airport), ai.airport_name 
from aircrafts a
join flights f on a.aircraft_code = f.aircraft_code
join airports ai on f.departure_airport = ai.airport_code 
where range = (select max(range) from aircrafts)

--Задание №3
--Вывести 10 рейсов с максимальным временем задержки вылета
-- время задержки считалось по вылетевшим  и совершившим посадку самолетам
select (actual_departure - scheduled_departure) as difftime, flight_no 
from flights
where status = 'Departed'  or status = 'Arrived' 
ORDER by difftime desc limit 10

--Задание №4
--Были ли брони, по которым не были получены посадочные талоны? 
select count(distinct (book_ref))
from boarding_passes bp
right join tickets t on bp.ticket_no = t.ticket_no 
where boarding_no is null
-- по 91388 броням не были получены посадочные талоны.

--Задание №5
/*Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.
Добавьте столбец с накопительным итогом суммарное накопление количества вывезенных пассажиров
из каждого аэропорта на каждый день. 
Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело 
из данного аэропорта на этом или более ранних рейсах за день.*/
with cte as (
select s.aircraft_code, count(s.fare_conditions) as sum_seat
from seats s
group by s.aircraft_code)
select f.flight_id, f.aircraft_code, date_trunc('day',f.actual_departure)
,sum(count(tf.ticket_no)) over (partition by f.departure_airport,date_trunc('day',f.actual_departure))
,count(tf.ticket_no) as viletelo 
,round(((cte.sum_seat-count(tf.ticket_no))::real/cte.sum_seat::real)*100) as proc_free_seat
from flights f
join ticket_flights tf on f.flight_id = tf.flight_id
join cte  on f.aircraft_code = cte.aircraft_code
where f.actual_departure is not null
group by f.departure_airport,f.flight_id,cte.sum_seat,date_trunc('day',f.actual_departure)

--Задание №6
--Найдите процентное соотношение перелетов по типам самолетов от общего количества.
select a.model,f.count as "Количество рейсов", round((f.count::real/(select sum("Количество перелетов")
from (select count(flight_id) as "Количество перелетов"
from flights 
group by aircraft_code) fl)::real)*100)
from aircrafts a
join (select aircraft_code,count(flight_id)
from flights 
group by aircraft_code) f on a.aircraft_code = f.aircraft_code


--Задание №7
--Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?
with busines as (
select  distinct fare_conditions, flight_id, amount
from ticket_flights
where fare_conditions = 'Business'),
Economy as (
select  distinct fare_conditions, flight_id, amount
from ticket_flights
where fare_conditions = 'Economy')
select b.flight_id, b.amount, a.city 
from busines b
join Economy e on e.flight_id = b.flight_id
join flights f on b.flight_id = f.flight_id
join airports a on f.arrival_airport = a.airport_name 
where b.amount < e.amount

--Задание №8
--Между какими городами нет прямых рейсов?
create view task_1 as
	with cte as (
select dep.departure_airport,dep2.arrival_airport 
from (select distinct departure_airport
from flights) as dep, (select distinct arrival_airport
from flights) as dep2
where dep.departure_airport != dep2.arrival_airport
except
select distinct departure_airport,arrival_airport
from flights)
select depart.depart_city, arr.arr_city
from cte
join (select airport_code as depart_code,  city as depart_city from airports) depart on cte.departure_airport = depart.depart_code   
join (select airport_code as arr_code,  city as arr_city from airports) arr on cte.arrival_airport = arr.arr_code

select * from task_1
where depart_city = 'Уфа'

--Задание №9
/*Вычислите расстояние между аэропортами, связанными прямыми рейсами,
сравните с допустимой максимальной дальностью перелетов в самолетах, обслуживающих эти рейсы*/ 
select * 
		,case 
			when plain < delta 
				then 'Недолет'
			else 'Долетел'
		end as "Результат"
from (
select flight_id
		,f.aircraft_code
		,f.departure_airport
		,dep_city
		,dep_longitude
		,dep_latitude
		,f.arrival_airport
		,arr_city
		,arr_longitude
		,arr_latitude
		,round((acos(sin(radians(dep_latitude))*sin(radians(arr_latitude))+cos(radians(dep_latitude))*cos(radians(arr_latitude))*cos(radians(dep_longitude)-radians(arr_longitude))))*6371) as delta
		,a.range as plain
from flights f 
join (select longitude as dep_longitude
			,latitude as dep_latitude
			,city as dep_city
			,airport_code from airports) dep on dep.airport_code = f.departure_airport
join (select longitude as arr_longitude
			,latitude as arr_latitude
			,city as arr_city
			,airport_code from airports) arr on arr.airport_code = f.arrival_airport
join aircrafts a on a.aircraft_code = f.aircraft_code 
) t

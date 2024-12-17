1. --кол-во посетителей
select count(distinct visitor_id) as total_visitors
from sessions;

2. --по дням
with tab1 (
    select 
    visit_date::date AS visit_day,
    case 
	when lower(source) like 'vk%' then 'vkontakte'
	when lower(source) like 'yandex%' then 'yandex'
	when lower(source) like 'twitter%' then 'twitter'
	when lower(source) like 'facebook%' then 'facebook'
	when lower(source) like 'telegram%' or lower(source) = 'tg' then 'telegram'
	else source
    end as
    source,
    count(distinct visitor_id) AS visitor_count
from sessions
group by 1,2
order by 1)

select 
	visit_day,
	case 
		when visitors_count < (select avg(visitors_count) from tab1) then 'others'
		else source
	end
	as source,
	sum (visitors_count)
	from tab1
	group by 1,2
	order by date;


-- по неделям
with tab1 as (
    select 
    date_trunc('week', visit_date) AS visit_week,
    case 
	when lower(source) like 'vk%' then 'vkontakte'
	when lower(source) like 'yandex%' then 'yandex'
	when lower(source) like 'twitter%' then 'twitter'
	when lower(source) like 'facebook%' then 'facebook'
	when lower(source) like 'telegram%' or lower(source) = 'tg' then 'telegram'
	else source
    end as
    source,
    count(distinct visitor_id) AS visitor_count
from sessions
group by 1,2
order by 1)

select 
	visit_week,
	case 
		when visitors_count < (select avg(visitors_count) from tab1) then 'others'
		else source
	end
	as source,
	sum (visitors_count)
	from tab1
	group by 1,2
	order by date;

3. -- кол-во лидов

select count(distinct lead_id) as total_leads
from leads;

4. -- конверсия в лида и в оплату

with total_visitors as (
    select count(distinct visitor_id) as total_visitors
    from sessions
),
total_leads as (
    select count(distinct lead_id) as total_leads
    from leads
),
total_paid as (
    select count(distinct lead_id) as paid_count
    from leads
    where status_id = '142')
    
select 
	(select paid_count from total_paid) as paid,
    (select total_leads from total_leads) as leads,
    (select total_visitors from total_visitors) as visitors,
    round((select total_leads from total_leads) * 100.0 / 
    (select total_visitors from total_visitors),2) as conversion_click_to_lead,
    round((select paid_count from total_paid) * 100.0 /
    (select total_leads from total_leads),2) as conversion_lead_to_payment;



5. -- расходы за каждый день

select 
    campaign_date::date as spend_day,
    utm_source,
    SUM(daily_spent) as total_spent
from vk_ads
group by 1,2
union all
select  
    campaign_date::date as spend_day,
    utm_source,
    SUM(daily_spent) as total_spent
from ya_ads
group by 1,2
order by 1,2;

6. --  окупаемость каналов

with ad_spending as (
    select 
        utm_source,
        sum(daily_spent) as total_spent
    from (
        select 
            utm_source,
            daily_spent
        from vk_ads
        union all
        select 
            utm_source,
            daily_spent
        from ya_ads
    ) as combined_ads
    group by utm_source
),
lead_income as (
    select 
        s.source,
        sum(l.amount) as total_income
    from leads l
    join sessions s on l.visitor_id = s.visitor_id
    group by 1
)

select 
    ads.utm_source,
    coalesce(sum(ads.total_spent), 0) as total_spent,
    coalesce(sum(li.total_income), 0) as total_income,
    coalesce(sum(li.total_income), 0) - coalesce(sum(ads.total_spent), 0) as profit
from ad_spending as ads
left join lead_income li on ads.utm_source = li.source
group by 1
order by 1;

7. -- итоговая таблица

WITH ad_spending AS (
    SELECT
        source,
        SUM(daily_spent) AS total_cost,
        DATE(campaign_date) AS ad_date
    FROM (
        SELECT
            vk.utm_source AS source,
            vk.daily_spent,
            vk.campaign_date
        FROM vk_ads vk
        UNION ALL
        SELECT
            ya.utm_source AS source,
            ya.daily_spent,
            ya.campaign_date
        FROM ya_ads ya
    ) AS combined_ads
    GROUP BY source, ad_date
),
lead_data AS (
    SELECT
        s.source,
        COUNT(DISTINCT s.visitor_id) AS visitors_count,
        COUNT(l.lead_id) AS leads_count,
        DATE(s.visit_date) AS visit_date
    FROM sessions s
    LEFT JOIN leads l ON s.visitor_id = l.visitor_id
    GROUP BY s.source, visit_date
),
sales_data AS (
    SELECT
        s.source,
        COUNT(sale.lead_id) AS purchases_count,
        SUM(sale.amount) AS revenue,
        DATE(s.visit_date) AS visit_date
    FROM sessions s
    LEFT JOIN leads sale ON s.visitor_id = sale.visitor_id
    GROUP BY s.source, visit_date
)

select DISTINCT
    ads.ad_date,
    ads.source,
    COALESCE(ads.total_cost, 0) AS total_cost,
    COALESCE(ld.visitors_count, 0) AS visitors_count,
    COALESCE(ld.leads_count, 0) AS leads_count,
    COALESCE(sd.purchases_count, 0) AS purchases_count,
    COALESCE(sd.revenue, 0) AS revenue,
    CASE
        WHEN COALESCE(ld.visitors_count, 0) > 0 THEN COALESCE(ads.total_cost, 0) / ld.visitors_count
        ELSE 0
    END AS cpu,
    CASE
        WHEN COALESCE(ld.leads_count, 0) > 0 THEN COALESCE(ads.total_cost, 0) / ld.leads_count
        ELSE 0
    END AS cpl,
    CASE
        WHEN COALESCE(sd.purchases_count, 0) > 0 THEN COALESCE(ads.total_cost, 0) / sd.purchases_count
        ELSE 0
    END AS cppu,
    CASE
        WHEN COALESCE(ads.total_cost, 0) > 0 THEN (COALESCE(sd.revenue, 0) - COALESCE(ads.total_cost, 0)) / COALESCE(ads.total_cost, 0) * 100
        ELSE 0
    END AS roi
FROM ad_spending ads
LEFT JOIN lead_data ld ON ads.source = ld.source AND ads.ad_date = ld.visit_date
LEFT JOIN sales_data sd ON ads.source = sd.source AND ads.ad_date = sd.visit_date
ORDER BY ads.ad_date, ads.source;
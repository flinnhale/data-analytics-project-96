with tab1 as (
    select
        s.visitor_id,
        date(s.visit_date) as visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc) as rn
    from sessions as s
    left join leads as l on s.visitor_id = l.visitor_id
    where s.medium in ('cpc', 'cpm', 'cpa', 'cpp', 'tg', 'youtube', 'social')   
),

last_paid_click as (
select
	utm_source,
	utm_medium,
	utm_campaign,
	count(visitor_id) as visitors_count,
	count(lead_id) as leads_count,
	visit_date,
	count(status_id) filter (where status_id = 142) as purchases_count,
	sum(amount) as revenue
from tab1
where rn = 1
group by 6,1,2,3),

ads as (

select 
	date(campaign_date) as campaign_date,
	utm_source,
	utm_medium,
	utm_campaign,
	sum(daily_spent) as total_spent
from vk_ads 
group by 1,2,3,4
union 
select 
	date(campaign_date) as campaign_date,
	utm_source,
	utm_medium,
	utm_campaign,
	sum(daily_spent) as total_spent
from ya_ads  
group by 1,2,3,4
order by 1)

select
    lpc.visit_date,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    lpc.visitors_count,
    ads.total_spent,
    lpc.leads_count,
    lpc.purchases_count,
    lpc.revenue
from last_paid_click as lpc
left join ads on lpc.utm_source = ads.utm_source
    		 and lpc.utm_medium = ads.utm_medium
             and lpc.utm_campaign = ads.utm_campaign
             and lpc.visit_date = ads.campaign_date
order by 9 desc nulls last, 1, 5 desc,2,3,4
limit 15
	
    

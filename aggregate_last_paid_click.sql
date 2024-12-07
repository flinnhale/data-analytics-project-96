with tab1 as (
    select
        s.visitor_id,
        s.visit_date,
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
    left join leads as l
        on s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

last_paid_click as (
    select
        date(visit_date) as visit_date,
        count(visitor_id) as visitors_count,
        utm_source,
        utm_medium,
        utm_campaign,
        count(lead_id) as leads_count,
        count(closing_reason) filter (where status_id = 142) as purchases_count,
        sum(amount) as revenue
    from tab1
    where rn = 1
    group by
        date(visit_date),
        utm_source,
        utm_medium,
        utm_campaign
),

ads as (
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
    union
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
    order by campaign_date
)

select
    lpv.visit_date,
    lpv.visitors_count,
    lpv.utm_source,
    lpv.utm_medium,
    lpv.utm_campaign,
    a.total_cost,
    lpv.leads_count,
    lpv.purchases_count,
    lpv.revenue
from last_paid_click as lpv
left join ads as a
    on lpv.utm_source = a.utm_source
    and lpv.utm_medium = a.utm_medium
    and lpv.utm_campaign = a.utm_campaign
    and lpv.visit_date = a.campaign_date
order by
    lpv.revenue desc nulls last,
    lpv.visit_date asc,
    lpv.visitors_count desc,
    lpv.utm_source asc,
    lpv.utm_medium asc,
    lpv.utm_campaign asc
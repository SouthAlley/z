# 从文件中读取域名规则列表
with open('https://raw.githubusercontent.com/SouthAlley/z/main/Surge/Rule/MyBlockAds.list', 'r') as file:
    rules = file.read().splitlines()

# 定义规则顺序
rule_order = ['DOMAIN', 'DOMAIN-SUFFIX', 'DOMAIN-KEYWORD', 'IP-CIDR', 'USER-AGENT']

# 对规则进行排序
sorted_rules = sorted(rules, key=lambda x: rule_order.index(x.split(',')[0]))

# 输出排序后的规则
for rule in sorted_rules:
    print(rule)

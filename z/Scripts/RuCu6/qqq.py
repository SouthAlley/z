# 定义文件路径
file_path = 'Surge/Rule/MyBlockAds.list'

# 从文件中读取域名规则列表
with open(file_path, 'r') as file:
    rules = file.read().splitlines()

# 定义规则顺序
rule_order = ['DOMAIN', 'DOMAIN-SUFFIX', 'DOMAIN-KEYWORD', 'IP-CIDR', 'USER-AGENT']

# 对规则进行排序
sorted_rules = sorted(
    (rule for rule in rules if rule.split(',')[0] in rule_order),
    key=lambda x: rule_order.index(x.split(',')[0])
)

# 将排序后的规则写回原文件
with open(file_path, 'w') as file:
    for rule in sorted_rules:
        file.write(rule + '\n')

print(f"Sorted rules have been written back to {file_path}")
